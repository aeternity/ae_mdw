defmodule AeMdw.Sync.AsyncTasks.WealthRank do
  @moduledoc """
  Wallet balance ranking.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation

  require Model

  @table :async_wealth_rank

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep balances :: [{pubkey(), integer()}]
  @opaque key :: {integer, pubkey()}

  @spec init() :: :ok
  def init do
    @table = :ets.new(@table, [:named_table, :set, :public])
    :ok
  end

  @spec prune_balance_ranking(AsyncStore.t()) :: {[key()], AsyncStore.t()}
  def prune_balance_ranking(store) do
    keys =
      store
      |> balance_accounts()
      |> Enum.reduce(%{}, fn {amount, pubkey}, acc -> Map.put_new(acc, pubkey, amount) end)
      |> Enum.map(fn {pubkey, amount} -> {amount, pubkey} end)
      |> Enum.sort_by(fn {amount, _pubkey} -> amount end, :desc)

    top_keys = Enum.take(keys, rank_size_config())

    cleared_store = Enum.reduce(keys, store, &AsyncStore.delete(&2, Model.BalanceAccount, &1))
    :ets.delete_all_objects(@table)

    {top_keys,
     Enum.reduce(top_keys, cleared_store, fn {amount, pubkey}, store ->
       insert(store, pubkey, amount)
     end)}
  end

  @spec restore_ranking(AsyncStore.t(), [key()]) :: AsyncStore.t()
  def restore_ranking(store, keys) do
    Enum.reduce(keys, store, fn {amount, pubkey}, store ->
      insert(store, pubkey, amount)
    end)
  end

  @spec rank_size_config :: integer()
  def rank_size_config do
    with nil <- :persistent_term.get({__MODULE__, :rank_size}, nil) do
      rank_size = Application.fetch_env!(:ae_mdw, :wealth_rank_size)
      :persistent_term.put({__MODULE__, :rank_size}, rank_size)
      rank_size
    end
  end

  @spec update_balances(balances()) :: :ok
  def update_balances(balances) do
    async_store =
      if AsyncStore.next(AsyncStore.instance(), Model.BalanceAccount, nil) == :none do
        init_wealth_store()
      else
        AsyncStore.instance()
      end

    _store =
      Enum.reduce(balances, async_store, fn {account_pk, balance}, store ->
        with old_balance when old_balance != nil <- get_balance(account_pk) do
          AsyncStore.delete(store, Model.BalanceAccount, {old_balance, account_pk})
        end

        insert(async_store, account_pk, balance)
      end)

    :ok
  end

  @spec dedup_pending_accounts() :: :ok
  def dedup_pending_accounts do
    state = State.new()

    {delete_keys, pubkeys_set} =
      state
      |> Collection.stream(Model.AsyncTask, nil)
      |> Stream.filter(fn {_ts, type} -> type == :store_acc_balance end)
      |> Stream.map(&State.fetch!(state, Model.AsyncTask, &1))
      |> Enum.map_reduce(MapSet.new(), fn
        Model.async_task(index: index, extra_args: []), acc ->
          {index, acc}

        Model.async_task(index: index, extra_args: [extra_args]), acc ->
          {index, MapSet.union(acc, extra_args)}
      end)

    with args when args != [] <- last_mb(state, nil) do
      task_index = {System.system_time(), :store_acc_balance}
      m_task = Model.async_task(index: task_index, args: args, extra_args: [pubkeys_set])

      State.commit_db(
        state,
        [
          DeleteKeysMutation.new(%{Model.AsyncTask => delete_keys}),
          WriteMutation.new(Model.AsyncTask, m_task)
        ],
        false
      )
    end

    :ok
  end

  defp last_mb(state, key) do
    case State.prev(state, Model.Block, key) do
      {:ok, {_height, -1} = prev_key} ->
        last_mb(state, prev_key)

      {:ok, block_index} ->
        Model.block(hash: mb_hash) = State.fetch!(state, Model.Block, block_index)
        [mb_hash, block_index]

      :none ->
        []
    end
  end

  defp init_wealth_store do
    async_store = AsyncStore.instance()

    State.new()
    |> Collection.stream(Model.BalanceAccount, :backward, nil, {nil, nil})
    |> Enum.reduce(async_store, fn {amount, pubkey}, store ->
      insert(store, pubkey, amount)
    end)
  end

  defp insert(async_store, pubkey, balance) do
    :ets.insert(@table, {pubkey, balance})

    record = Model.balance_account(index: {balance, pubkey})
    AsyncStore.put(async_store, Model.BalanceAccount, record)
  end

  defp get_balance(pubkey) do
    case :ets.lookup(@table, pubkey) do
      [{^pubkey, balance}] -> balance
      [] -> nil
    end
  end

  defp balance_accounts(store) do
    store
    |> AsyncStore.prev(Model.BalanceAccount, {nil, nil})
    |> Stream.unfold(fn
      :none -> nil
      {:ok, key} -> {key, AsyncStore.prev(store, Model.BalanceAccount, key)}
    end)
    |> Enum.to_list()
  end
end
