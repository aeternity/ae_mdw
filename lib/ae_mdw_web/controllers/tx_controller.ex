defmodule AeMdwWeb.TxController do
  use AeMdwWeb, :controller

  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
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
  Counts all transactions for a given scope, type or address.
  """
  def count(%Conn{assigns: %{state: state, scope: scope, query: query}} = conn, _params) do
    case Txs.count(state, scope, query) do
      {:ok, count} -> json(conn, count)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec count_id(Conn.t(), map()) :: Conn.t()
  @doc """
  Counts each field for all transaction types where this address is present.
  """
  def count_id(%Conn{assigns: %{state: state}} = conn, %{"id" => id, "type_group" => group}) do
    with {:ok, tx_type_group} <- Validate.tx_group(group),
         {:ok, pubkey} <- Validate.id(id) do
      json(conn, count_id_type_group(state, pubkey, tx_type_group))
    end
  end

  def count_id(%Conn{assigns: %{state: state}} = conn, %{"id" => id, "type" => type}) do
    with {:ok, tx_type} <- Validate.tx_type(type),
         {:ok, pubkey} <- Validate.id(id) do
      json(conn, count_id_type(state, pubkey, tx_type))
    end
  end

  def count_id(%Conn{assigns: %{state: state}} = conn, %{"id" => id}) do
    with {:ok, pubkey} <- Validate.id(id) do
      json(conn, id_counts(state, pubkey))
    end
  end

  ##########

  @spec id_counts(State.t(), binary()) :: map()
  defp id_counts(state, <<_::256>> = pk) do
    for tx_type <- Node.tx_types(), reduce: %{} do
      counts ->
        tx_counts =
          for {field, pos} <- Node.tx_ids(tx_type), reduce: %{} do
            tx_counts ->
              case State.get(state, Model.IdCount, {tx_type, pos, pk}) do
                :not_found -> tx_counts
                {:ok, Model.id_count(count: count)} -> Map.put(tx_counts, field, count)
              end
          end

        (map_size(tx_counts) == 0 &&
           counts) ||
          Map.put(counts, tx_type, tx_counts)
    end
  end

  defp count_id_type(state, pubkey, tx_type) do
    tx_type
    |> Node.tx_ids_positions()
    |> Enum.reduce(0, fn field_pos, sum ->
      case State.get(state, Model.IdCount, {tx_type, field_pos, pubkey}) do
        :not_found -> sum
        {:ok, Model.id_count(count: count)} -> sum + count
      end
    end)
  end

  defp count_id_type_group(state, pubkey, tx_type_group) do
    tx_type_group
    |> Node.tx_group()
    |> Enum.reduce(0, fn tx_type, sum ->
      sum + count_id_type(state, pubkey, tx_type)
    end)
  end

  @spec micro_block_txs(Conn.t(), map()) :: Conn.t()
  def micro_block_txs(%Conn{assigns: assigns} = conn, %{"hash" => hash}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, prev_cursor, txs, next_cursor} <-
           Txs.fetch_micro_block_txs(state, hash, pagination, cursor) do
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

  defp extract_group(key, val, group) do
    {_is_base_id?, validator} = AeMdw.Db.Stream.Query.Parser.classify_ident(key)

    try do
      {:ok, MapSet.put(group, {key, validator.(val)})}
    rescue
      err in [AeMdw.Error.Input] ->
        {:error, err}
    end
  end
end
