defmodule AeMdwWeb.GraphQL.Resolvers.TransactionResolver do
  @moduledoc """
  Transaction-related resolvers: single transaction lookup, paginated transactions, micro block
  transactions and key block micro blocks.

  NOTE: Currently only a subset of REST filtering is exposed (account + type), enough for parity
  tests. Extend incrementally as needed.
  """
  alias AeMdw.{Txs, Blocks}
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate

  @max_limit 100

  # ---------------- Single Transaction ----------------
  @spec transaction(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def transaction(_p, %{id: id}, %{context: %{state: state}}) when not is_nil(state) do
    cond do
      id =~ ~r/^\d+$/ -> fetch_by_index(state, id)
      true -> fetch_by_hash(state, id)
    end
  end

  def transaction(_, _args, _), do: {:error, "partial_state_unavailable"}

  defp fetch_by_index(state, idx_str) do
    case Integer.parse(idx_str) do
      {txi, ""} ->
        case Txs.fetch(state, txi, add_spendtx_details?: true, render_v3?: true) do
          {:ok, tx} -> {:ok, atomize_tx(tx)}
          {:error, %ErrInput.NotFound{}} -> {:error, "transaction_not_found"}
          {:error, _} -> {:error, "transaction_error"}
        end

      _ ->
        {:error, "invalid_transaction_id"}
    end
  end

  defp fetch_by_hash(state, hash) do
    with {:ok, _bin} <- Validate.id(hash),
         {:ok, tx} <- Txs.fetch(state, hash, add_spendtx_details?: true, render_v3?: true) do
      {:ok, atomize_tx(tx)}
    else
      {:error, %ErrInput.NotFound{}} -> {:error, "transaction_not_found"}
      {:error, _} -> {:error, "transaction_error"}
    end
  end

  # ---------------- Transactions List ----------------
  @spec transactions(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def transactions(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    from_txi = Map.get(args, :from_txi)
    to_txi = Map.get(args, :to_txi)
    from_height = Map.get(args, :from_height) || get_in(args, [:filter, :from_height])
    to_height = Map.get(args, :to_height) || get_in(args, [:filter, :to_height])
    account = Map.get(args, :account)
    type = Map.get(args, :type)
    filter = Map.get(args, :filter) || %{}
    account = Map.get(filter, :account, account)
    type = Map.get(filter, :type, type)

    range =
      cond do
        from_txi && to_txi -> {:txi, from_txi..to_txi}
        to_txi && is_nil(from_txi) -> {:txi, 0..to_txi}
        from_txi && is_nil(to_txi) -> {:txi, from_txi..from_txi}
        from_height && to_height -> {:gen, from_height..to_height}
        to_height && is_nil(from_height) -> {:gen, 0..to_height}
        from_height && is_nil(to_height) -> {:gen, from_height..from_height}
        true -> nil
      end

    pagination = {:backward, false, limit, not is_nil(cursor)}

    with {:ok, query} <- build_query_filters(account, type),
         {:ok, {prev, txs, next}} <-
           Txs.fetch_txs(state, pagination, range, query, cursor, render_v3?: true) do
      data = Enum.map(txs, &atomize_tx/1)
      {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: data}}
    else
      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, %ErrInput.Scope{}} -> {:error, "invalid_scope"}
      {:error, _} -> {:error, "transactions_error"}
    end
  end

  def transactions(_, _args, _), do: {:error, "partial_state_unavailable"}

  # ---------------- Transactions Count ----------------
  @spec transactions_count(any, map(), Absinthe.Resolution.t()) ::
          {:ok, integer()} | {:error, String.t()}
  def transactions_count(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    from_txi = Map.get(args, :from_txi)
    to_txi = Map.get(args, :to_txi)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    account = Map.get(args, :account)
    type = Map.get(args, :type)
    filter = Map.get(args, :filter) || %{}
    account = Map.get(filter, :account, account)
    type = Map.get(filter, :type, type)

    range =
      cond do
        from_txi && to_txi -> {:txi, from_txi..to_txi}
        to_txi && is_nil(from_txi) -> {:txi, 0..to_txi}
        from_txi && is_nil(to_txi) -> {:txi, from_txi..from_txi}
        from_height && to_height -> {:gen, from_height..to_height}
        to_height && is_nil(from_height) -> {:gen, 0..to_height}
        from_height && is_nil(to_height) -> {:gen, from_height..from_height}
        true -> nil
      end

    # AeMdw.Txs.count only supports specific param maps with string keys.
    params =
      cond do
        account && type -> %{"id" => account, "type" => type}
        account -> %{"id" => account}
        type -> %{"type" => type}
        true -> %{}
      end

    # Underlying count doesn't support combining range with filters; return error early.
    if range && map_size(params) > 0 do
      {:error, "invalid_filter"}
    else
      case AeMdw.Txs.count(state, range, params) do
        {:ok, cnt} -> {:ok, cnt}
        {:error, %ErrInput.Query{}} -> {:error, "invalid_filter"}
        _ -> {:error, "transactions_count_error"}
      end
    end
  end

  def transactions_count(_, _args, _), do: {:error, "partial_state_unavailable"}

  # ---------------- Pending Transactions List ----------------
  @spec pending_transactions(any, map(), Absinthe.Resolution.t()) ::
          {:ok, map()} | {:error, String.t()}
  def pending_transactions(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    try do
      {prev, txs, next} = AeMdw.Txs.fetch_pending_txs(state, pagination, nil, cursor)
      data = Enum.map(txs, &atomize_tx/1)
      {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: data}}
    rescue
      _ -> {:error, "pending_transactions_error"}
    end
  end

  def pending_transactions(_, _args, _), do: {:error, "partial_state_unavailable"}

  # ---------------- Pending Transactions Count ----------------
  @spec pending_transactions_count(any, map(), Absinthe.Resolution.t()) ::
          {:ok, integer()} | {:error, String.t()}
  def pending_transactions_count(_p, _args, _res) do
    try do
      {:ok, AeMdw.Node.Db.pending_txs_count()}
    rescue
      _ -> {:error, "pending_transactions_count_error"}
    end
  end

  # ---------------- Micro Block Transactions ----------------
  @spec micro_block_transactions(any, map(), Absinthe.Resolution.t()) ::
          {:ok, map()} | {:error, String.t()}
  def micro_block_transactions(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    hash = Map.fetch!(args, :hash)
    account = Map.get(args, :account)
    type = Map.get(args, :type)

    pagination = {:backward, false, limit, not is_nil(cursor)}

    with {:ok, query} <- build_query_filters(account, type),
         {:ok, {prev, txs, next}} <-
           Txs.fetch_micro_block_txs(state, hash, query, pagination, cursor, render_v3?: true) do
      data = Enum.map(txs, &atomize_tx/1)
      {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: data}}
    else
      {:error, %ErrInput.NotFound{}} -> {:error, "micro_block_not_found"}
      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, _} -> {:error, "micro_block_transactions_error"}
    end
  end

  def micro_block_transactions(_, _args, _), do: {:error, "partial_state_unavailable"}

  # ---------------- Key Block Micro Blocks ----------------
  @spec key_block_micro_blocks(any, map(), Absinthe.Resolution.t()) ::
          {:ok, map()} | {:error, String.t()}
  def key_block_micro_blocks(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    id = Map.fetch!(args, :id)

    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Blocks.fetch_key_block_micro_blocks(state, id, pagination, cursor) do
      {:ok, {prev, micro_blocks, next}} ->
        data = Enum.map(micro_blocks, &normalize_micro_block/1)
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: data}}

      {:error, %ErrInput.NotFound{}} ->
        {:error, "key_block_not_found"}

      {:error, %ErrInput.Cursor{}} ->
        {:error, "invalid_cursor"}

      {:error, _} ->
        {:error, "key_block_micro_blocks_error"}
    end
  end

  def key_block_micro_blocks(_, _args, _), do: {:error, "partial_state_unavailable"}

  # ---------------- Helpers ----------------
  defp normalize_micro_block(block) do
    %{
      hash: Map.get(block, :hash) || Map.get(block, "hash"),
      height: Map.get(block, :height) || Map.get(block, "height"),
      time: Map.get(block, :time) || Map.get(block, "time"),
      micro_block_index:
        Map.get(block, :micro_block_index) || Map.get(block, "micro_block_index"),
      transactions_count:
        Map.get(block, :transactions_count) || Map.get(block, "transactions_count"),
      gas: Map.get(block, :gas) || Map.get(block, "gas"),
      pof_hash: Map.get(block, :pof_hash) || Map.get(block, "pof_hash"),
      prev_hash: Map.get(block, :prev_hash) || Map.get(block, "prev_hash"),
      state_hash: Map.get(block, :state_hash) || Map.get(block, "state_hash"),
      txs_hash: Map.get(block, :txs_hash) || Map.get(block, "txs_hash"),
      signature: Map.get(block, :signature) || Map.get(block, "signature"),
      miner: Map.get(block, :miner) || Map.get(block, "miner")
    }
  end

  defp build_query_filters(nil, nil), do: {:ok, %{}}

  defp build_query_filters(account, type) do
    with {:ok, query} <- base_query(account), do: add_type(query, type)
  end

  defp base_query(nil), do: {:ok, %{}}

  defp base_query(account) do
    case Validate.id(account) do
      {:ok, account_pk} -> {:ok, %{ids: MapSet.new([{"account", account_pk}])}}
      {:error, _} -> {:error, ErrInput.Query.exception(value: "invalid_account")}
    end
  end

  defp add_type(query, nil), do: {:ok, query}

  defp add_type(query, type) do
    case Validate.tx_type(type) do
      {:ok, tx_type} ->
        {:ok, Map.update(query, :types, MapSet.new([tx_type]), &MapSet.put(&1, tx_type))}

      {:error, _} ->
        {:error, ErrInput.Query.exception(value: "invalid_type")}
    end
  end

  defp atomize_tx(tx_map) do
    tx_map =
      Enum.reduce(tx_map, %{}, fn
        {k, v}, acc when is_binary(k) -> Map.put(acc, String.to_atom(k), v)
        {k, v}, acc -> Map.put(acc, k, v)
      end)

    encoded_tx =
      case Map.get(tx_map, :tx) do
        m when is_map(m) -> Jason.encode!(m)
        other -> Jason.encode!(other)
      end

    base = Map.put(tx_map, :tx, encoded_tx)

    inner =
      case Jason.decode(encoded_tx) do
        {:ok, m} -> m
        _ -> %{}
      end

    # promote common fields if present
    promoted =
      Enum.reduce(
        ~w(fee type gas gas_price nonce sender_id recipient_id amount ttl payload)a,
        %{},
        fn key, acc ->
          kstr = to_string(key)
          val = Map.get(tx_map, key) || Map.get(inner, kstr)
          if is_nil(val), do: acc, else: Map.put(acc, key, val)
        end
      )

    Map.merge(base, promoted)
  end

  defp cursor_val(nil), do: nil
  defp cursor_val({val, _rev}), do: val

  defp clamp_limit(l) when is_integer(l) and l > @max_limit, do: @max_limit
  defp clamp_limit(l) when is_integer(l) and l > 0, do: l
  defp clamp_limit(_), do: 20
end
