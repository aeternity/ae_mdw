defmodule AeMdw.Migrations.SyncBalanceAccount do
  @moduledoc """
    The account balance has become corrupted, so we need to sync it with the balances from the node
  """
  alias AeMdw.Collection
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Logger
  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    current_height = State.height(state)
    all_keys = state |> Collection.stream(Model.BalanceAccount, :forward) |> Enum.to_list()

    clear_mutation = DeleteKeysMutation.new(%{Model.BalanceAccount => all_keys})

    {wrong_balances_count, write_mutations} =
      Enum.reduce(all_keys, {0, []}, fn {old_balance, account_id},
                                        {count_acc, write_mutations_acc} ->
        new_balance = :aeapi.balance_at_height(account_id, current_height)

        write_mutation =
          WriteMutation.new(
            Model.BalanceAccount,
            Model.balance_account(index: {new_balance, account_id})
          )

        if new_balance != old_balance do
          {count_acc + 1, [write_mutation | write_mutations_acc]}
        else
          {count_acc, [write_mutation | write_mutations_acc]}
        end
      end)

    Logger.warning("Found #{wrong_balances_count} wrong balances")
    _state = State.commit(state, [clear_mutation | write_mutations])

    {:ok, wrong_balances_count}
  end
end
