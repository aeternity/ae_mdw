defmodule AeMdwWeb.TxController do
  use AeMdwWeb, :controller

  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream.Query.Parser
  alias AeMdw.Txs
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdw.Util
  alias Plug.Conn

  require Model

  import AeMdwWeb.Util

  @type_query_params ~w(type type_group)
  @pagination_param_keys ~w(limit page cursor expand direction scope_type range by rev scope tx_hash)

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  ##########

  @spec tx(Conn.t(), map()) :: Conn.t()
  def tx(%Conn{assigns: %{state: state}} = conn, %{"hash_or_index" => hash_or_index} = params) do
    case Util.parse_int(hash_or_index) do
      {:ok, _txi} ->
        txi(conn, Map.put(params, "index", hash_or_index))

      :error ->
        with {:ok, tx_hash} <- Validate.id(hash_or_index),
             {:ok, tx} <- Txs.fetch(state, tx_hash) do
          json(conn, tx)
        end
    end
  end

  @spec txi(Conn.t(), map()) :: Conn.t()
  def txi(%Conn{assigns: %{state: state}} = conn, %{"index" => index}) do
    with {:ok, txi} <- Validate.nonneg_int(index),
         {:ok, tx} <- Txs.fetch(state, txi) do
      json(conn, tx)
    end
  end

  @spec txs(Conn.t(), map()) :: Conn.t()
  def txs(%Conn{assigns: assigns, query_params: query_params} = conn, params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns
    add_spendtx_details? = Map.has_key?(params, "account")

    with {:ok, query} <- extract_query(query_params),
         {:ok, prev_cursor, txs, next_cursor} <-
           Txs.fetch_txs(state, pagination, scope, query, cursor, add_spendtx_details?) do
      paginate(conn, prev_cursor, txs, next_cursor)
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
        json(conn, %{data: count})
      end
    else
      with {:ok, count} <- Txs.count(state, scope, query) do
        json(conn, count)
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
      json(conn, Txs.count_id_type_group(state, pubkey, tx_type_group))
    end
  end

  def count_id(%Conn{assigns: %{state: state}} = conn, %{"id" => id, "type" => type}) do
    with {:ok, tx_type} <- Validate.tx_type(type),
         {:ok, pubkey} <- Validate.id(id) do
      json(conn, Txs.count_id_type(state, pubkey, tx_type))
    end
  end

  def count_id(%Conn{assigns: %{state: state}} = conn, %{"id" => id}) do
    with {:ok, pubkey} <- Validate.id(id) do
      json(conn, Txs.id_counts(state, pubkey))
    end
  end

  @spec micro_block_txs(Conn.t(), map()) :: Conn.t()
  def micro_block_txs(%Conn{assigns: assigns, query_params: query_params} = conn, %{
        "hash" => hash
      }) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    with :ok <- validate_without_scope(scope),
         {:ok, query} <- extract_query(query_params),
         {:ok, prev_cursor, txs, next_cursor} <-
           Txs.fetch_micro_block_txs(state, hash, query, pagination, cursor) do
      paginate(conn, prev_cursor, txs, next_cursor)
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
