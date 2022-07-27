defmodule AeMdwWeb.TxController do
  use AeMdwWeb, :controller

  alias AeMdw.Node
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Txs
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdw.Node
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
      {:error, reason} ->
        send_error(conn, :bad_request, reason)
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
  def count_id(%Conn{assigns: %{state: state}} = conn, %{"id" => id}),
    do: handle_input(conn, fn -> conn |> json(id_counts(state, Validate.id!(id))) end)

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
end
