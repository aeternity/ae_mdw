defmodule AeMdw.Sync.AsyncTasks.WealthRank do
  @moduledoc """
  Wallet balance ranking.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @table :async_wealth_rank
  @rank_size 100

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @opaque key :: {integer, pubkey()}

  @spec init() :: :ok
  def init do
    @table = :ets.new(@table, [:named_table, :set, :public])
    :ok
  end

  @spec init_wealth_store() :: :ok
  def init_wealth_store do
    async_store = AsyncStore.instance()

    State.new()
    |> Collection.stream(Model.BalanceAccount, :backward, nil, {nil, nil})
    |> Enum.each(
      &AsyncStore.put(async_store, Model.BalanceAccount, Model.balance_account(index: &1))
    )

    :ok
  end

  @spec insert(pubkey(), integer()) :: :ok
  def insert(pubkey, balance) do
    :ets.insert(@table, {pubkey, balance})
    :ok
  end

  @spec get_balance(pubkey()) :: integer() | nil
  def get_balance(pubkey) do
    case :ets.lookup(@table, pubkey) do
      [{^pubkey, balance}] -> balance
      [] -> nil
    end
  end

  @spec prune_balance_ranking(AsyncStore.t()) :: {[key()], AsyncStore.t()}
  def prune_balance_ranking(store) do
    keys = balance_accounts(store)
    top_keys = Enum.take(keys, @rank_size)

    cleared_store = Enum.reduce(keys, store, &AsyncStore.delete(&2, Model.BalanceAccount, &1))
    :ets.delete_all_objects(@table)

    {top_keys,
     Enum.reduce(top_keys, cleared_store, fn key, store ->
       AsyncStore.put(store, Model.BalanceAccount, Model.balance_account(index: key))
     end)}
  end

  @spec restore_ranking(AsyncStore.t(), [key()]) :: AsyncStore.t()
  def restore_ranking(store, keys) do
    Enum.reduce(keys, store, fn key, store ->
      AsyncStore.put(store, Model.BalanceAccount, Model.balance_account(index: key))
    end)
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
