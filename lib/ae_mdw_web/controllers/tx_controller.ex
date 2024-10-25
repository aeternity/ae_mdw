defmodule AeMdwWeb.TxController do
  use AeMdwWeb, :controller

  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.NodeStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Stream.Query.Parser
  alias AeMdw.Txs
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdw.Util
  alias AeMdwWeb.Util, as: WebUtil
  alias Plug.Conn

  require Model

  @type_query_params ~w(type type_group)
  @pagination_param_keys ~w(limit page cursor expand direction scope_type range by rev scope tx_hash)

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  ##########

  @spec tx(Conn.t(), map()) :: Conn.t()
  def tx(%Conn{assigns: %{state: state}} = conn, %{"hash" => hash}) do
    with {:ok, tx_hash} <- Validate.id(hash),
         {:ok, tx} <- Txs.fetch(state, tx_hash, add_spendtx_details?: true, render_v3?: true) do
      format_json(conn, tx)
    end
  end

  def tx(%Conn{assigns: %{state: state}} = conn, %{"hash_or_index" => hash_or_index} = params) do
    case Util.parse_int(hash_or_index) do
      {:ok, _txi} ->
        txi(conn, Map.put(params, "index", hash_or_index))

      :error ->
        with {:ok, tx_hash} <- Validate.id(hash_or_index),
             {:ok, tx} <- Txs.fetch(state, tx_hash, add_spendtx_details?: true, render_v3?: true) do
          format_json(conn, tx)
        end
    end
  end

  @spec tx_v2(Conn.t(), map()) :: Conn.t()
  def tx_v2(%Conn{assigns: %{state: state}} = conn, %{"hash" => hash}) do
    with {:ok, tx_hash} <- Validate.id(hash),
         {:ok, tx} <- Txs.fetch(state, tx_hash, add_spendtx_details?: true) do
      format_json(conn, tx)
    end
  end

  def tx_v2(%Conn{assigns: %{state: state}} = conn, %{"hash_or_index" => hash_or_index} = params) do
    case Util.parse_int(hash_or_index) do
      {:ok, _txi} ->
        txi(conn, Map.put(params, "index", hash_or_index))

      :error ->
        with {:ok, tx_hash} <- Validate.id(hash_or_index),
             {:ok, tx} <- Txs.fetch(state, tx_hash, add_spendtx_details?: true) do
          format_json(conn, tx)
        end
    end
  end

  @spec txi(Conn.t(), map()) :: Conn.t()
  def txi(%Conn{assigns: %{state: state}} = conn, %{"index" => index}) do
    with {:ok, txi} <- Validate.nonneg_int(index),
         {:ok, tx} <- Txs.fetch(state, txi, add_spendtx_details?: true) do
      format_json(conn, tx)
    end
  end

  @spec txs(Conn.t(), map()) :: Conn.t()
  def txs(%Conn{assigns: assigns} = conn, params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query_params} =
      assigns

    opts = [add_spendtx_details?: Map.has_key?(params, "account")]

    with {:ok, query} <- extract_query(query_params),
         {:ok, paginated_txs} <-
           Txs.fetch_txs(state, pagination, scope, query, cursor, [{:render_v3?, true} | opts]) do
      WebUtil.render(conn, paginated_txs)
    else
      {:error, reason} when is_binary(reason) -> {:error, ErrInput.Query.exception(value: reason)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec txs_v2(Conn.t(), map()) :: Conn.t()
  def txs_v2(%Conn{assigns: assigns} = conn, params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query_params} =
      assigns

    opts = [add_spendtx_details?: Map.has_key?(params, "account")]

    with {:ok, query} <- extract_query(query_params),
         {:ok, paginated_txs} <- Txs.fetch_txs(state, pagination, scope, query, cursor, opts) do
      WebUtil.render(conn, paginated_txs)
    else
      {:error, reason} when is_binary(reason) -> {:error, ErrInput.Query.exception(value: reason)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec count(Conn.t(), map()) :: Conn.t()
  @doc """
  Counts all transactions for a given scope, type, address or micro-block (along with types).
  """
  def count(%Conn{assigns: %{state: state, scope: scope, query: query}} = conn, _params) do
    {mb_hash, query} = Map.pop(query, "mb_hash")

    if mb_hash != nil do
      with :ok <- validate_without_scope(scope),
           {:ok, query} <- extract_query(query),
           {:ok, count} <- Txs.count_micro_block_txs(state, mb_hash, query) do
        format_json(conn, %{data: count})
      end
    else
      with {:ok, count} <- Txs.count(state, scope, query) do
        format_json(conn, count)
      end
    end
  end

  @spec count_id(Conn.t(), map()) :: Conn.t()
  @doc """
  Counts each field for all transaction types where this address is present.
  """
  def count_id(%Conn{assigns: %{state: state}} = conn, %{"id" => id, "type_group" => group}) do
    with {:ok, tx_type_group} <- Validate.tx_group(group),
         {:ok, pubkey} <- Validate.id(id) do
      format_json(conn, Txs.count_id_type_group(state, pubkey, tx_type_group))
    end
  end

  def count_id(%Conn{assigns: %{state: state}} = conn, %{"id" => id, "type" => type}) do
    with {:ok, tx_type} <- Validate.tx_type(type),
         {:ok, pubkey} <- Validate.id(id) do
      format_json(conn, Txs.count_id_type(state, pubkey, tx_type))
    end
  end

  def count_id(%Conn{assigns: %{state: state}} = conn, %{"id" => id}) do
    with {:ok, pubkey} <- Validate.id(id) do
      format_json(conn, Txs.id_counts(state, pubkey))
    end
  end

  @spec micro_block_txs(Conn.t(), map()) :: Conn.t()
  def micro_block_txs(%Conn{assigns: assigns} = conn, %{"hash" => hash}) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query_params} =
      assigns

    with :ok <- validate_without_scope(scope),
         {:ok, query} <- extract_query(query_params),
         {:ok, paginated_txs} <-
           Txs.fetch_micro_block_txs(state, hash, query, pagination, cursor, render_v3?: true) do
      WebUtil.render(conn, paginated_txs)
    end
  end

  @spec micro_block_txs_v2(Conn.t(), map()) :: Conn.t()
  def micro_block_txs_v2(%Conn{assigns: assigns} = conn, %{"hash" => hash}) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query_params} =
      assigns

    with :ok <- validate_without_scope(scope),
         {:ok, query} <- extract_query(query_params),
         {:ok, paginated_txs} <- Txs.fetch_micro_block_txs(state, hash, query, pagination, cursor) do
      WebUtil.render(conn, paginated_txs)
    end
  end

  @spec pending_txs(Conn.t(), map()) :: Conn.t()
  def pending_txs(%Conn{assigns: assigns} = conn, _params) do
    %{state: _state, pagination: pagination, cursor: cursor, scope: scope} =
      assigns

    NodeStore.new()
    |> State.new()
    |> Txs.fetch_pending_txs(pagination, scope, cursor)
    |> then(&WebUtil.render(conn, &1))
  end

  @spec pending_txs_count(Conn.t(), map()) :: Conn.t()
  def pending_txs_count(%Conn{} = conn, _params) do
    format_json(conn, Db.pending_txs_count())
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
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_group("type_group", val, group) do
    case Validate.tx_group(val) do
      {:ok, new_group} ->
        {:ok, new_group |> Node.tx_group() |> MapSet.new() |> MapSet.union(group)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_group("entrypoint", val, group), do: {:ok, MapSet.put(group, {"entrypoint", val})}

  defp extract_group(key, val, group) do
    validator = Parser.classify_ident(key)

    try do
      {:ok, MapSet.put(group, {key, validator.(val)})}
    rescue
      err in [AeMdw.Error.Input] ->
        {:error, err}
    end
  end

  defp validate_without_scope(nil), do: :ok
  defp validate_without_scope(_scope), do: {:error, {ErrInput.Query, "scope not allowed"}}
end
