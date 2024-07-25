defmodule AeMdwWeb.Plugs.PaginatedPlug do
  @moduledoc false

  import Plug.Conn

  alias AeMdw.Db.Util, as: DbUtil
  alias Phoenix.Controller
  alias Plug.Conn

  @typep opt() ::
           {:order_by, [atom()]}
           | {:txi_scope?, boolean()}
           | {:max_limit, pos_integer()}
  @type opts() :: [opt()]

  @scope_types %{
    "gen" => :gen,
    "txi" => :txi,
    "time" => :time
  }
  @scope_types_keys Map.keys(@scope_types)

  @default_limit 10
  @max_limit 100

  @default_scope nil

  @pagination_params ~w(limit cursor rev direction scope tx_hash expand by int-as-string)

  @spec init(opts()) :: opts()
  def init(opts), do: opts

  @spec call(Conn.t(), opts()) :: Conn.t()
  def call(
        %Conn{params: params, query_params: query_params, assigns: %{state: state}} = conn,
        opts
      ) do
    txi_scope? = Keyword.get(opts, :txi_scope?, true)
    max_limit = Keyword.get(opts, :max_limit, @max_limit)

    with {:ok, direction, scope} <- extract_direction_and_scope(params, txi_scope?, state),
         {:ok, limit} <- extract_limit(params, max_limit),
         {:ok, is_reversed?} <- extract_is_reversed(params),
         {:ok, order_by} <- extract_order_by(params, opts),
         {:ok, page} <- extract_page(params),
         {:ok, opts} <- extract_opts(params) do
      cursor = Map.get(params, "cursor")

      conn
      |> assign(:pagination, {direction, is_reversed?, limit, !is_nil(cursor)})
      |> assign(:cursor, cursor)
      |> assign(:opts, opts)
      |> assign(:order_by, order_by)
      |> assign(:scope, scope)
      |> assign(:offset, {limit, page})
      |> assign(:query, Map.drop(query_params, @pagination_params))
    else
      {:error, error_msg} ->
        conn
        |> put_status(:bad_request)
        |> Controller.json(%{"error" => error_msg})
        |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp extract_direction_and_scope(%{"range_or_dir" => "forward"}, _txi_scope?, _state),
    do: {:ok, :forward, @default_scope}

  defp extract_direction_and_scope(%{"range_or_dir" => "backward"}, _txi_scope?, _state),
    do: {:ok, :backward, @default_scope}

  defp extract_direction_and_scope(%{"range_or_dir" => range} = params, txi_scope?, state) do
    params
    |> Map.delete("range_or_dir")
    |> Map.put("range", range)
    |> extract_direction_and_scope(txi_scope?, state)
  end

  defp extract_direction_and_scope(
         %{"scope_type" => scope_type, "range" => range} = params,
         _txi_scope? = true,
         state
       )
       when scope_type in @scope_types_keys do
    scope_type = Map.fetch!(@scope_types, scope_type)

    case extract_range(range) do
      {:ok, first, last} when first < last ->
        {:forward, generate_range(state, scope_type, first, last)}

      {:ok, first, last} when first > last ->
        {:backward, generate_range(state, scope_type, last, first)}

      {:ok, first, last} ->
        if Map.get(params, "direction", "backward") == "forward" do
          {:forward, generate_range(state, scope_type, last, first)}
        else
          {:backward, generate_range(state, scope_type, last, first)}
        end

      {:error, reason} ->
        {nil, {:error, reason}}
    end
    |> case do
      {_direction, {:error, reason}} -> {:error, reason}
      {direction, range} -> {:ok, direction, range}
    end
  end

  defp extract_direction_and_scope(
         %{"scope_type" => scope_type} = params,
         _txi_scope? = false,
         state
       )
       when scope_type in ["gen", "time"] do
    extract_direction_and_scope(params, true, state)
  end

  defp extract_direction_and_scope(%{"scope_type" => scope_type}, _txi_scope?, _state),
    do: {:error, "invalid scope: #{scope_type}"}

  defp extract_direction_and_scope(%{"range" => _range} = params, txi_scope?, state),
    do: extract_direction_and_scope(Map.put(params, "scope_type", "gen"), txi_scope?, state)

  defp extract_direction_and_scope(%{"scope" => scope} = params, txi_scope?, state) do
    case String.split(scope, ":") do
      [scope_type, range] ->
        params
        |> Map.delete("scope")
        |> Map.merge(%{"scope_type" => scope_type, "range" => range})
        |> extract_direction_and_scope(txi_scope?, state)

      _invalid_scope ->
        {:error, "invalid scope: #{scope}"}
    end
  end

  defp extract_direction_and_scope(%{"direction" => "forward"}, _txi_scope?, _state),
    do: {:ok, :forward, @default_scope}

  defp extract_direction_and_scope(%{"direction" => "backward"}, _txi_scope?, _state),
    do: {:ok, :backward, @default_scope}

  defp extract_direction_and_scope(%{"direction" => direction}, _txi_scope?, _state),
    do: {:error, "invalid direction: #{direction}"}

  defp extract_direction_and_scope(_params, _txi_scope?, _state),
    do: {:ok, :backward, @default_scope}

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

  defp extract_limit(params, max_limit) do
    limit_bin = Map.get(params, "limit", "#{@default_limit}")

    case Integer.parse(limit_bin) do
      {limit, ""} when limit <= max_limit and limit > 0 -> {:ok, limit}
      {limit, ""} when limit > max_limit -> {:error, "limit too large: #{limit}"}
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

  # Page extraction from params is for backwards compat and should be removed
  # after getting rid of non-cursor-based pagination.
  defp extract_page(%{"page" => page}) do
    case Integer.parse(page) do
      {page, ""} -> {:ok, page}
      _err_or_invalid -> {:error, "invalid_page: #{page}"}
    end
  end

  defp extract_page(_params), do: {:ok, 1}

  defp extract_is_reversed(params), do: {:ok, match?(%{"rev" => "1"}, params)}

  defp extract_opts(params) do
    expand? = Map.get(params, "expand", "false") != "false"
    tx_hash? = Map.get(params, "tx_hash", "false") != "false"

    if expand? and tx_hash? do
      {:error, "either `tx_hash` or `expand` parameters should be used, but not both."}
    else
      {:ok,
       [
         expand?: expand?,
         top: Map.get(params, "top", "false") != "false",
         tx_hash?: tx_hash?
       ]}
    end
  end

  @spec generate_range(State.t(), atom(), pos_integer(), pos_integer()) ::
          {atom(), Range.t()} | {:error, atom()}
  defp generate_range(state, :time, first, last) do
    with {_first, {:ok, first_parsed}} <- {first, DateTime.from_unix(first)},
         {_last, {:ok, last_parsed}} <- {last, DateTime.from_unix(last)} do
      {first_txi, last_txi} =
        DbUtil.time_to_txi(
          state,
          DateTime.to_unix(first_parsed, :millisecond),
          DateTime.to_unix(last_parsed, :millisecond)
        )

      generate_range(state, :txi, first_txi, last_txi)
    else
      {invalid_unix_time, {:error, _reason}} ->
        {:error, "invalid unix time: #{invalid_unix_time}"}
    end
  end

  defp generate_range(_state, scope_type, first, last) do
    {scope_type, first..last}
  end
end
