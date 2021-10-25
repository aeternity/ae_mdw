defmodule AeMdwWeb.DataStreamPlug do
  import Plug.Conn

  alias AeMdw.Validate
  alias AeMdw.Node, as: AE
  alias Plug.Conn

  import AeMdw.Db.Util, only: [first_gen: 0, last_gen: 0]
  import AeMdwWeb.Util, only: [concat: 2]

  @default_limit 10
  @max_limit 1000
  @behaviour Plug

  ##########

  @impl true
  def init(opts),
    do: {Keyword.fetch!(opts, :paginables), Keyword.fetch!(opts, :scopes)}

  @impl true
  def call(%Conn{path_info: [_path_slice1, "count" | _path_slice3]} = conn, _opts),
    do: conn

  def call(%Conn{} = conn, {[], _scopes}),
    do: conn

  def call(%Plug.Conn{path_info: path_info} = conn, {[{prefix, hook} | paginables], scopes}) do
    case {List.starts_with?(path_info, prefix), hook} do
      {true, nil} ->
        default_parse(conn, Enum.drop(path_info, Enum.count(prefix)), scopes)

      {true, hook} when is_function(hook, 1) ->
        hook.(conn)

      {false, _} ->
        call(conn, {paginables, scopes})
    end
  end

  ##########

  defp default_parse(conn, rem_path, scopes) do
    handle_assign(
      conn,
      parse_scope(rem_path, scopes),
      parse_offset(conn.query_params),
      parse_query(conn.query_string)
    )
  end

  @spec handle_assign(Conn.t(), term(), term(), term()) :: Conn.t()
  def handle_assign(conn, maybe_scope, maybe_offset, maybe_query) do
    with {:ok, scope} <- maybe_scope,
         {:ok, offset} <- maybe_offset,
         {:ok, query} <- maybe_query do
      conn
      |> assign(:scope, scope)
      |> assign(:offset, offset)
      |> assign(:query, query)
    else
      {:error, reason} ->
        conn
        |> AeMdwWeb.Util.send_error(400, reason)
        |> halt
    end
  end

  ##########

  @spec parse_scope([binary()], [binary()]) :: {:ok, term()} | {:error, binary()}
  def parse_scope(["forward" | _rem_path], _scopes),
    do: {:ok, {:gen, first_gen()..last_gen()}}

  def parse_scope(["backward" | _rem_path], _scopes),
    do: {:ok, {:gen, last_gen()..first_gen()}}

  def parse_scope([], _scopes),
    do: {:ok, {:gen, last_gen()..first_gen()}}

  def parse_scope([scope_type, range | _rem_path], scopes) do
    if scope_type in scopes do
      case parse_range(range) do
        {:ok, range} ->
          {:ok, {String.to_existing_atom(scope_type), range}}

        {:error, detail} ->
          {:error, concat("invalid range", detail)}
      end
    else
      {:error, concat("invalid scope", scope_type)}
    end
  end

  def parse_scope([direction | _rem_path], _scopes),
    do: {:error, concat("invalid direction", direction)}

  @spec parse_range(binary()) :: {:ok, Range.t()} | {:error, binary}
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

      _invalid_range ->
        {:error, range}
    end
  end

  @spec parse_offset(map()) :: {:ok, {non_neg_integer(), pos_integer()}} | {:error, binary()}
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

  defp query_norm(types, "type", val) do
    case Validate.tx_type(val) do
      {:ok, type} ->
        {:ok, MapSet.put(types, type)}

      {:error, {err_kind, offender}} ->
        {:error, AeMdw.Error.to_string(err_kind, offender)}
    end
  end

  defp query_norm(types, "type_group", val) do
    case Validate.tx_group(val) do
      {:ok, group} ->
        {:ok, group |> AE.tx_group() |> MapSet.new() |> MapSet.union(types)}

      {:error, {err_kind, offender}} ->
        {:error, AeMdw.Error.to_string(err_kind, offender)}
    end
  end

  defp query_norm(ids, key_spec, val) do
    {_, validator} = AeMdw.Db.Stream.Query.Parser.classify_ident(key_spec)

    try do
      {:ok, MapSet.put(ids, {key_spec, validator.(val)})}
    rescue
      err in [AeMdw.Error.Input] ->
        {:error, err.message}
    end
  end

  defp parse_query("" <> query_string),
    do: parse_query(URI.query_decoder(query_string))

  @type_params ["type", "type_group"]
  defp parse_query(stream) do
    get = fn kw, top -> Map.get(top, kw, MapSet.new()) end

    stream
    |> Enum.filter(fn {k, _v} -> k not in ["limit", "page", "cursor", "expand"] end)
    |> Enum.reduce_while(
      {:ok, %{}},
      fn {key, val}, {:ok, top_level} ->
        kw = (key in @type_params && :types) || :ids
        group = get.(kw, top_level)

        case query_norm(group, key, val) do
          {:ok, group} ->
            {:cont, {:ok, Map.put(top_level, kw, group)}}

          {:error, message} ->
            {:halt, {:error, message}}
        end
      end
    )
  end
end
