defmodule AeMdwWeb.Plugs.PaginatedPlug do
  @moduledoc false

  import Plug.Conn

  alias AeMdw.Db.Model
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Txs
  alias AeMdw.Validate
  alias Phoenix.Controller
  alias Plug.Conn

  require Model

  @typep opt() ::
           {:order_by, [atom()]}
           | {:txi_scope?, boolean()}
           | {:max_limit, pos_integer()}
  @type opts() :: [opt()]

  @scope_types %{
    "gen" => :gen,
    "txi" => :txi,
    "time" => :time,
    "epoch" => :epoch,
    "transaction" => :tx
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
        %Conn{params: params, query_params: _query_params, assigns: %{state: state}} = conn,
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
      |> clean_query()
    else
      {:error, %ErrInput{message: message}} ->
        conn
        |> put_status(:bad_request)
        |> Controller.json(%{"error" => message})
        |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp extract_direction_and_scope(
         %{"scope" => "transaction:" <> transaction_scope} = params,
         _txi_scope,
         state
       ) do
    with tx_hashes when length(tx_hashes) > 0 and length(tx_hashes) <= 2 <-
           String.split(transaction_scope, "-"),
         {:ok, txis} <- tx_hashes_to_txis(tx_hashes, state) do
      case txis do
        [from, to] -> generate_range(state, :txi, from, to, params)
        [single] -> generate_range(state, :txi, single, single, params)
      end
    else
      {:error, reason} -> {:error, reason}
      _invalid_scope -> {:error, ErrInput.Scope.exception(value: transaction_scope)}
    end
  end

  defp extract_direction_and_scope(
         %{"scope_type" => scope_type, "range" => range} = params,
         _txi_scope? = true,
         state
       )
       when scope_type in @scope_types_keys do
    scope_type = Map.fetch!(@scope_types, scope_type)

    extract_range(state, scope_type, range, params)
  end

  defp extract_direction_and_scope(
         %{"scope_type" => scope_type} = params,
         _txi_scope? = false,
         state
       )
       when scope_type in ["gen", "time", "epoch", "transaction"] do
    extract_direction_and_scope(params, true, state)
  end

  defp extract_direction_and_scope(%{"scope_type" => scope_type}, _txi_scope?, _state),
    do: {:error, ErrInput.Scope.exception(value: scope_type)}

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
        {:error, ErrInput.Scope.exception(value: scope)}
    end
  end

  defp extract_direction_and_scope(%{"direction" => "forward"}, _txi_scope?, _state),
    do: {:ok, :forward, @default_scope}

  defp extract_direction_and_scope(%{"direction" => "backward"}, _txi_scope?, _state),
    do: {:ok, :backward, @default_scope}

  defp extract_direction_and_scope(%{"direction" => direction}, _txi_scope?, _state),
    do: {:error, ErrInput.Query.exception(value: "invalid direction `#{direction}`")}

  defp extract_direction_and_scope(_params, _txi_scope?, _state),
    do: {:ok, :backward, @default_scope}

  defp extract_range(state, scope_type, range, params) when is_binary(range) do
    case String.split(range, "-") do
      [from, to] ->
        case {Integer.parse(from), Integer.parse(to)} do
          {{from, ""}, {to, ""}} when from >= 0 and to >= 0 ->
            generate_range(state, scope_type, from, to, params)

          {_from_err, _to_err} ->
            {:error, ErrInput.Scope.exception(value: range)}
        end

      [single] ->
        case Integer.parse(single) do
          {single, ""} when single >= 0 ->
            generate_range(state, scope_type, single, single, params)

          _single_err ->
            {:error, ErrInput.Scope.exception(value: range)}
        end

      _splitted_range ->
        {:error, ErrInput.Scope.exception(value: range)}
    end
  end

  defp extract_range(_state, _scope_type, range, _params),
    do: {:error, ErrInput.Scope.exception(value: "invalid range: #{inspect(range)}")}

  defp generate_range(state, :time, first, last, params) do
    with {_first, {:ok, first_parsed}} <- {first, DateTime.from_unix(first)},
         {_last, {:ok, last_parsed}} <- {last, DateTime.from_unix(last)} do
      {first_txi, last_txi} =
        DbUtil.time_to_txi(
          state,
          DateTime.to_unix(first_parsed, :millisecond),
          DateTime.to_unix(last_parsed, :millisecond)
        )

      generate_range(state, :txi, first_txi, last_txi, params)
    else
      {invalid_unix_time, {:error, _reason}} ->
        {:error, ErrInput.Scope.exception(value: "invalid unix time `#{invalid_unix_time}`")}
    end
  end

  defp generate_range(_state, scope_type, first, last, _params) when first < last do
    {:ok, :forward, {scope_type, first..last}}
  end

  defp generate_range(_state, scope_type, first, last, _params) when last < first do
    {:ok, :backward, {scope_type, last..first}}
  end

  defp generate_range(_state, scope_type, first, last, params) do
    if Map.get(params, "direction", "backward") == "forward" do
      {:ok, :forward, {scope_type, last..first}}
    else
      {:ok, :backward, {scope_type, last..first}}
    end
  end

  defp extract_limit(params, max_limit) do
    limit_bin = Map.get(params, "limit", "#{@default_limit}")

    case Integer.parse(limit_bin) do
      {limit, ""} when limit <= max_limit and limit > 0 ->
        {:ok, limit}

      {limit, ""} when limit > max_limit ->
        {:error, ErrInput.Query.exception(value: "limit too large `#{limit}`")}

      {_limit, _rest} ->
        {:error, ErrInput.Query.exception(value: "invalid limit `#{limit_bin}`")}

      :error ->
        {:error, ErrInput.Query.exception(value: "invalid limit `#{limit_bin}`")}
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
          nil -> {:error, ErrInput.Query.exception(value: "by=#{order_by}")}
          valid_order_by -> {:ok, valid_order_by}
        end
    end
  end

  # Page extraction from params is for backwards compat and should be removed
  # after getting rid of non-cursor-based pagination.
  defp extract_page(%{"page" => page}) do
    case Integer.parse(page) do
      {page, ""} -> {:ok, page}
      _err_or_invalid -> {:error, ErrInput.Query.exception(value: "invalid_page `#{page}`")}
    end
  end

  defp extract_page(_params), do: {:ok, 1}

  defp extract_is_reversed(params), do: {:ok, match?(%{"rev" => "1"}, params)}

  defp extract_opts(params) do
    expand? = Map.get(params, "expand", "false") != "false"
    tx_hash? = Map.get(params, "tx_hash", "false") != "false"

    if expand? and tx_hash? do
      {:error,
       ErrInput.Query.exception(
         value: "either `tx_hash` or `expand` parameters should be used, but not both."
       )}
    else
      {:ok,
       [
         expand?: expand?,
         top: Map.get(params, "top", "false") != "false",
         tx_hash?: tx_hash?
       ]}
    end
  end

  defp tx_hashes_to_txis(tx_hashes, state) do
    Enum.reduce_while(tx_hashes, {:ok, []}, fn tx_hash, {:ok, txis} ->
      with {:ok, tx_hash} <- Validate.hash(tx_hash, :tx_hash),
           {:ok, txi} <- Txs.tx_hash_to_txi(state, tx_hash) do
        {:cont, {:ok, txis ++ [txi]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp clean_query(%Conn{query_params: query_params} = conn) do
    query_params
    |> Map.drop(@pagination_params)
    |> Map.reject(fn {key, _val} -> String.starts_with?(key, "_") end)
    |> then(&assign(conn, :query, &1))
  end
end
