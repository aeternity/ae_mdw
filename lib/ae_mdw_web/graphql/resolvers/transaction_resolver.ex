defmodule AeMdwWeb.GraphQL.Resolvers.TransactionResolver do
  alias AeMdw.Txs
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate
  alias AeMdwWeb.GraphQL.Resolvers.Helpers
  alias AeMdw.Db.NodeStore
  alias AeMdw.Db.State

  def transaction(_p, %{hash: hash}, %{context: %{state: state}}) do
    with {:ok, tx_hash} <- Validate.id(hash),
         {:ok, tx} <- Txs.fetch(state, tx_hash, add_spendtx_details?: true, render_v3?: true) do
      {:ok, atomize_tx(tx)}
    else
      {:error, err} -> {:error, ErrInput.message(err)}
    end
  end

  def pending_transactions(_p, args, _res) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    try do
      {prev, txs, next} =
        NodeStore.new()
        |> State.new()
        |> Txs.fetch_pending_txs(pagination, nil, cursor)

      {:ok,
       %{
         prev_cursor: Helpers.cursor_val(prev),
         next_cursor: Helpers.cursor_val(next),
         data: txs |> Enum.map(&atomize_tx/1)
       }}
    rescue
      _ -> {:error, "pending_transactions_error"}
    end
  end

  def pending_transactions_count(_p, _args, _res) do
    try do
      {:ok, AeMdw.Node.Db.pending_txs_count()}
    rescue
      _ -> {:error, "pending_transactions_count_error"}
    end
  end

  defp atomize_tx(tx_map) do
    %{
      block_hash: tx_map["block_hash"],
      block_height: tx_map["block_height"],
      encoded_tx: tx_map["encoded_tx"],
      hash: tx_map["hash"],
      micro_index: tx_map["micro_index"],
      micro_time: tx_map["micro_time"],
      signatures: tx_map["signatures"],
      tx: tx_map["tx"]
    }
  end

  # ---------------- Transactions List ----------------
  # @spec transactions(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  # def transactions(_p, args, %{context: %{state: state}}) when not is_nil(state) do
  #  limit = clamp_limit(Map.get(args, :limit, 20))
  #  cursor = Map.get(args, :cursor)
  #  from_txi = Map.get(args, :from_txi)
  #  to_txi = Map.get(args, :to_txi)
  #  from_height = Map.get(args, :from_height) || get_in(args, [:filter, :from_height])
  #  to_height = Map.get(args, :to_height) || get_in(args, [:filter, :to_height])
  #  account = Map.get(args, :account)
  #  type = Map.get(args, :type)
  #  filter = Map.get(args, :filter) || %{}
  #  account = Map.get(filter, :account, account)
  #  type = Map.get(filter, :type, type)

  #  range =
  #    cond do
  #      from_txi && to_txi -> {:txi, from_txi..to_txi}
  #      to_txi && is_nil(from_txi) -> {:txi, 0..to_txi}
  #      from_txi && is_nil(to_txi) -> {:txi, from_txi..from_txi}
  #      from_height && to_height -> {:gen, from_height..to_height}
  #      to_height && is_nil(from_height) -> {:gen, 0..to_height}
  #      from_height && is_nil(to_height) -> {:gen, from_height..from_height}
  #      true -> nil
  #    end

  #  pagination = {:backward, false, limit, not is_nil(cursor)}

  #  with {:ok, query} <- build_query_filters(account, type),
  #       {:ok, {prev, txs, next}} <-
  #         Txs.fetch_txs(state, pagination, range, query, cursor, render_v3?: true) do
  #    data = Enum.map(txs, &atomize_tx/1)
  #    {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: data}}
  #  else
  #    {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
  #    {:error, %ErrInput.Scope{}} -> {:error, "invalid_scope"}
  #    {:error, _} -> {:error, "transactions_error"}
  #  end
  # end

  # def transactions(_, _args, _), do: {:error, "partial_state_unavailable"}

  ## ---------------- Transactions Count ----------------
  # @spec transactions_count(any, map(), Absinthe.Resolution.t()) ::
  #        {:ok, integer()} | {:error, String.t()}
  # def transactions_count(_p, args, %{context: %{state: state}}) when not is_nil(state) do
  #  from_txi = Map.get(args, :from_txi)
  #  to_txi = Map.get(args, :to_txi)
  #  from_height = Map.get(args, :from_height)
  #  to_height = Map.get(args, :to_height)
  #  account = Map.get(args, :account)
  #  type = Map.get(args, :type)
  #  filter = Map.get(args, :filter) || %{}
  #  account = Map.get(filter, :account, account)
  #  type = Map.get(filter, :type, type)

  #  range =
  #    cond do
  #      from_txi && to_txi -> {:txi, from_txi..to_txi}
  #      to_txi && is_nil(from_txi) -> {:txi, 0..to_txi}
  #      from_txi && is_nil(to_txi) -> {:txi, from_txi..from_txi}
  #      from_height && to_height -> {:gen, from_height..to_height}
  #      to_height && is_nil(from_height) -> {:gen, 0..to_height}
  #      from_height && is_nil(to_height) -> {:gen, from_height..from_height}
  #      true -> nil
  #    end

  #  # AeMdw.Txs.count only supports specific param maps with string keys.
  #  params =
  #    cond do
  #      account && type -> %{"id" => account, "type" => type}
  #      account -> %{"id" => account}
  #      type -> %{"type" => type}
  #      true -> %{}
  #    end

  #  # Underlying count doesn't support combining range with filters; return error early.
  #  if range && map_size(params) > 0 do
  #    {:error, "invalid_filter"}
  #  else
  #    case AeMdw.Txs.count(state, range, params) do
  #      {:ok, cnt} -> {:ok, cnt}
  #      {:error, %ErrInput.Query{}} -> {:error, "invalid_filter"}
  #      _ -> {:error, "transactions_count_error"}
  #    end
  #  end
  # end

  # def transactions_count(_, _args, _), do: {:error, "partial_state_unavailable"}

  ## ---------------- Helpers ----------------
  # defp build_query_filters(nil, nil), do: {:ok, %{}}

  # defp build_query_filters(account, type) do
  #  with {:ok, query} <- base_query(account), do: add_type(query, type)
  # end

  # defp base_query(nil), do: {:ok, %{}}

  # defp base_query(account) do
  #  case Validate.id(account) do
  #    {:ok, account_pk} -> {:ok, %{ids: MapSet.new([{"account", account_pk}])}}
  #    {:error, _} -> {:error, ErrInput.Query.exception(value: "invalid_account")}
  #  end
  # end

  # defp add_type(query, nil), do: {:ok, query}

  # defp add_type(query, type) do
  #  case Validate.tx_type(type) do
  #    {:ok, tx_type} ->
  #      {:ok, Map.update(query, :types, MapSet.new([tx_type]), &MapSet.put(&1, tx_type))}

  #    {:error, _} ->
  #      {:error, ErrInput.Query.exception(value: "invalid_type")}
  #  end
  # end
end
