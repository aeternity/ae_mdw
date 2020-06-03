defmodule AeMdwWeb.DataStreamPlug do
  import Plug.Conn

  alias AeMdw.Validate
  alias AeMdw.Node, as: AE

  import AeMdw.Db.Util, only: [first_gen: 0, last_gen: 0]
  import AeMdwWeb.Util, only: [concat: 2]

  @default_limit 10
  @max_limit 1000

  ##########

  def init(opts),
    do: {Keyword.fetch!(opts, :paginables), Keyword.fetch!(opts, :scopes)}

  def call(%Plug.Conn{path_info: [_, "count" | _]} = conn, _),
    do: conn

  def call(%Plug.Conn{path_info: [top_endpoint | rem_path]} = conn, {paginables, scopes}) do
    cond do
      top_endpoint in paginables ->
        with {:ok, scope} <- parse_scope(rem_path, scopes),
             {:ok, offset} <- parse_offset(conn.query_params),
             {:ok, query} <- parse_query(conn.query_string) do
          conn
          |> assign(:scope, scope)
          |> assign(:offset, offset)
          |> assign(:query, query)
        else
          {:error, reason} ->
            conn
            |> send_resp(400, Jason.encode!(%{error: reason}))
            |> halt
        end

      true ->
        conn
    end
  end

  ##########

  def parse_scope(["forward" | _], _),
    do: {:ok, {:gen, first_gen()..last_gen()}}

  def parse_scope(["backward" | _], _),
    do: {:ok, {:gen, last_gen()..first_gen()}}

  def parse_scope([scope_type, range | _], scopes) do
    cond do
      scope_type in scopes ->
        case parse_range(range) do
          {:ok, range} ->
            {:ok, {String.to_atom(scope_type), range}}

          {:error, detail} ->
            {:error, concat("invalid range", detail)}
        end

      true ->
        {:error, concat("invalid scope", scope_type)}
    end
  end

  def parse_range(range) do
    case String.split(range, "-") do
      [from, to] ->
        case {Validate.nonneg_int(from), Validate.nonneg_int(to)} do
          {{:ok, from}, {:ok, to}} -> {:ok, from..to}
          {{:ok, _}, {:error, {_, detail}}} -> {:error, detail}
          {{:error, {_, detail}}, _} -> {:error, detail}
        end

      [x] ->
        case Validate.nonneg_int(x) do
          {:ok, x} -> {:ok, x..x}
          {:error, {_, detail}} -> {:error, detail}
        end

      _ ->
        {:error, range}
    end
  end

  def parse_offset(%{"limit" => _, "page" => _} = m) do
    with {:ok, {limit, _}} <- parse_offset(Map.drop(m, ["page"])),
         {:ok, {_, page}} <- parse_offset(Map.drop(m, ["limit"])) do
      {:ok, {limit, page}}
    else
      err -> err
    end
  end

  def parse_offset(%{"limit" => limit}) do
    case Validate.nonneg_int(limit) do
      {:ok, limit} ->
        ensure_limit(limit, 1)

      {:error, {_, detail}} ->
        {:error, concat("invalid limit", detail)}
    end
  end

  def parse_offset(%{"page" => page}) do
    case Validate.nonneg_int(page) do
      {:ok, page} ->
        {:ok, {@default_limit, page}}

      {:error, {_, detail}} ->
        {:error, concat("invalid page", detail)}
    end
  end

  def parse_offset(%{}),
    do: {:ok, {@default_limit, 1}}

  defp ensure_limit(limit, page) when limit <= @max_limit,
    do: {:ok, {limit, page}}

  defp ensure_limit(limit, _page) when limit > @max_limit,
    do: {:error, concat("limit too large", limit)}

  ################################################################################

  def query_norm(types, "type", val) do
    case Validate.tx_type(val) do
      {:ok, type} -> {:ok, MapSet.put(types, type)}
      err -> err
    end
  end

  def query_norm(types, "type_group", val) do
    case Validate.tx_group(val) do
      {:ok, group} -> {:ok, MapSet.new(AE.tx_group(group)) |> MapSet.union(types)}
      err -> err
    end
  end

  def query_norm(ids, key_spec, val) do
    case Validate.id(val) do
      {:ok, pk} -> {:ok, MapSet.put(ids, {key_spec, pk})}
      err -> err
    end
  end

  def parse_query("" <> query_string),
    do: parse_query(URI.query_decoder(query_string))

  @type_params ["type", "type_group"]
  def parse_query(stream) do
    get = fn kw, top -> Map.get(top, kw, MapSet.new()) end

    stream
    |> Enum.filter(fn {k, _v} -> k not in ["limit", "page"] end)
    |> Enum.reduce_while(
      {:ok, %{}},
      fn {key, val}, {:ok, top_level} ->
        kw = (key in @type_params && :types) || :ids
        group = get.(kw, top_level)

        case query_norm(group, key, val) do
          {:ok, group} ->
            {:cont, {:ok, Map.put(top_level, kw, group)}}

          {:error, {err_kind, offender}} ->
            {:halt, {:error, AeMdw.Error.to_string(err_kind, offender)}}
        end
      end
    )
  end
end
