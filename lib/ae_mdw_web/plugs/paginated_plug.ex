defmodule AeMdwWeb.Plugs.PaginatedPlug do
  @moduledoc """
  """

  import Plug.Conn

  alias Phoenix.Controller
  alias Plug.Conn
  alias AeMdw.Db.Model.Block
  alias AeMdw.Mnesia
  alias AeMdw.Node
  alias AeMdw.Validate

  @type opts() :: [order_by: [atom()] | Plug.opts()]

  @scope_types %{
    "gen" => :gen,
    "txi" => :txi
  }
  @scope_types_keys Map.keys(@scope_types)

  @default_limit 10
  @max_limit 100

  @type_query_params ~w(type type_group)
  @pagination_param_keys ~w(limit page cursor expand direction scope_type range by)

  @spec init(opts()) :: opts()
  def init(opts), do: opts

  @spec call(Conn.t(), opts()) :: Conn.t()
  def call(%Conn{params: params, query_params: query_params} = conn, opts) do
    with {:ok, direction, scope} <- extract_direction_and_scope(params),
         {:ok, limit} <- extract_limit(params),
         {:ok, order_by} <- extract_order_by(params, opts),
         {:ok, query} <- extract_query(query_params),
         {:ok, page} <- extract_page(params) do
      conn
      |> assign(:direction, direction)
      |> assign(:cursor, Map.get(params, "cursor"))
      |> assign(:limit, limit)
      |> assign(:expand?, Map.get(params, "expand", "false") != "false")
      |> assign(:order_by, order_by)
      |> assign(:scope, scope)
      |> assign(:query, query)
      |> assign(:offset, {limit, page})
    else
      {:error, error_msg} ->
        conn
        |> put_status(:bad_request)
        |> Controller.json(%{"error" => error_msg})
        |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp extract_direction_and_scope(%{"scope_type" => scope_type, "range" => range})
       when scope_type in @scope_types_keys do
    scope_type = Map.fetch!(@scope_types, scope_type)

    case extract_range(range) do
      {:ok, first, last} when first <= last -> {:ok, :forward, {scope_type, first..last}}
      {:ok, first, last} -> {:ok, :backward, {scope_type, first..last}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_direction_and_scope(%{"scope_type" => scope_type}),
    do: {:error, "invalid scope: #{scope_type}"}

  defp extract_direction_and_scope(%{"direction" => "forward"}),
    do: {:ok, :forward, {:gen, default_forward_range()}}

  defp extract_direction_and_scope(%{"direction" => "backward"}),
    do: {:ok, :backward, {:gen, default_backward_range()}}

  defp extract_direction_and_scope(%{"direction" => direction}),
    do: {:error, "invalid direction: #{direction}"}

  defp extract_direction_and_scope(_params),
    do: {:ok, :backward, {:gen, default_backward_range()}}

  defp extract_range(range) when is_binary(range) do
    case String.split(range, "-") do
      [from, to] ->
        case {Integer.parse(from), Integer.parse(to)} do
          {{from, ""}, {to, ""}} when from >= 0 and to >= 0 -> {:ok, from, to}
          {_from_err, _to_err} -> {:error, "invalid range: #{range}"}
        end

      [single] ->
        case Integer.parse(single) do
          {single, ""} when single >= 0 -> {:ok, single, single}
          _single_err -> {:error, "invalid range: #{range}"}
        end

      _splitted_range ->
        {:error, "invalid range: #{range}"}
    end
  end

  defp extract_range(range), do: {:error, "invalid range: #{range}"}

  defp extract_limit(params) do
    limit_bin = Map.get(params, "limit", "#{@default_limit}")

    case Integer.parse(limit_bin) do
      {limit, ""} when limit <= @max_limit and limit > 0 -> {:ok, limit}
      {limit, ""} -> {:error, "limit too large: #{limit}"}
      {_limit, _rest} -> {:error, "invalid limit: #{limit_bin}"}
      :error -> {:error, "invalid limit: #{limit_bin}"}
    end
  end

  defp extract_order_by(params, opts) do
    case {Keyword.get(opts, :order_by), Map.get(params, "by")} do
      {nil, _order_by} ->
        {:ok, nil}

      {[first_order | _rest], nil} ->
        {:ok, first_order}

      {valid_orders, order_by} ->
        case Enum.find(valid_orders, &(Atom.to_string(&1) == order_by)) do
          nil -> {:error, "invalid query: by=#{order_by}"}
          valid_order_by -> {:ok, valid_order_by}
        end
    end
  end

  defp extract_query(query_params) do
    query_params
    |> Enum.reject(fn {key, _val} -> key in @pagination_param_keys end)
    |> Enum.reduce_while({:ok, %{}}, fn {key, val}, {:ok, top_level} ->
      kw = (key in @type_query_params && :types) || :ids
      group = Map.get(top_level, kw, MapSet.new())

      case extract_group(key, val, group) do
        {:ok, new_group} -> {:cont, {:ok, Map.put(top_level, kw, new_group)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp extract_group("type", val, group) do
    case Validate.tx_type(val) do
      {:ok, type} -> {:ok, MapSet.put(group, type)}
      {:error, {err_kind, offender}} -> {:error, AeMdw.Error.to_string(err_kind, offender)}
    end
  end

  defp extract_group("type_group", val, group) do
    case Validate.tx_group(val) do
      {:ok, new_group} ->
        {:ok, new_group |> Node.tx_group() |> MapSet.new() |> MapSet.union(group)}

      {:error, {err_kind, offender}} ->
        {:error, AeMdw.Error.to_string(err_kind, offender)}
    end
  end

  defp extract_group(key, val, group) do
    {_is_base_id?, validator} = AeMdw.Db.Stream.Query.Parser.classify_ident(key)

    try do
      {:ok, MapSet.put(group, {key, validator.(val)})}
    rescue
      err in [AeMdw.Error.Input] ->
        {:error, err.message}
    end
  end

  defp default_forward_range, do: first_gen()..last_gen()

  defp default_backward_range, do: last_gen()..first_gen()

  defp first_gen do
    case Mnesia.first_key(Block, nil) do
      nil -> 0
      {kbi, _txi} -> kbi
    end
  end

  defp last_gen do
    case Mnesia.last_key(Block, nil) do
      nil -> 0
      {kbi, _txi} -> kbi
    end
  end

  # Page extraction from params is for backwards compat and should be removed
  # after getting rid of non-cursor-based pagination.
  defp extract_page(%{"page" => page}) do
    case Integer.parse(page) do
      {page, ""} -> {:ok, page}
      _err_or_invalid -> {:error, "invalid_page: #{page}"}
    end
  end

  defp extract_page(_params), do: {:ok, 1}
end
