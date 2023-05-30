defmodule AeMdw.Sync.AsyncTasks.StoreAccountBalance do
  @moduledoc """
  Get and store account balance.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.WealthRank
  alias AeMdw.Log

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
          WealthRank.update_balances(balances)
        end
      end)

    done_fn.()

    if time_delta / @milisecs > @log_threshold_ms do
      Log.info(
        "[store_account_balance] #{inspect(block_index)} after #{time_delta / @milisecs}ms"
      )
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
end
