defmodule AeMdw.Sync.AsyncTasks.StoreAccountBalance do
  @moduledoc """
  Get and store account balance.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Db.Model
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Sync.AsyncTasks.WealthRank
  alias AeMdw.Log

  # alias AeMdw.Sync.AsyncStoreServer

  require Model
  require Logger

  @milisecs 1_000
  @log_threshold_ms 3

  @spec process(args :: list(), done_fn :: fun()) :: :ok
  def process([block_hash, block_index, account_set], done_fn) do
    {time_delta, _res} =
      :timer.tc(fn ->
        with {:value, trees} <- :aec_db.find_block_state_partial(block_hash, true, [:accounts]),
             accounts_tree <- :aec_trees.accounts(trees),
             balances <- get_balances(accounts_tree, account_set) do
          update_balances(balances)
        end
      end)

    done_fn.()

    if time_delta / @milisecs > @log_threshold_ms do
      Log.info("[store_account_balance] #{inspect(block_index)} after #{time_delta / @milisecs}s")
    end

    :ok
  end

  defp get_balances(accounts_tree, account_set) do
    account_set
    |> MapSet.to_list()
    |> Enum.flat_map(fn pubkey ->
      case :aec_accounts_trees.lookup(pubkey, accounts_tree) do
        {:value, account} -> [{pubkey, :aec_accounts.balance(account)}]
        :none -> []
      end
    end)
  end

  defp update_balances(balances) do
    async_store = AsyncStore.instance()

    if AsyncStore.next(async_store, Model.BalanceAccount, nil) == :none do
      WealthRank.init_wealth_store()
    end

    Enum.each(balances, fn {account_pk, balance} ->
      with old_balance when old_balance != nil <- WealthRank.get_balance(account_pk) do
        AsyncStore.delete(async_store, Model.BalanceAccount, {old_balance, account_pk})
      end

      WealthRank.insert(account_pk, balance)
      record = Model.balance_account(index: {balance, account_pk})
      AsyncStore.put(async_store, Model.BalanceAccount, record)
    end)
  end
end
