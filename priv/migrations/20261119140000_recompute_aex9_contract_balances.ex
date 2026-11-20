defmodule AeMdw.Migrations.RecomputeAex9ContractBalances do
  @moduledoc """
  Sets the total of every AEX-9 contract (the event_supply) to the sum of its
  stored balances. The dry-run recompute migrations moved the total by the
  balances they changed, while running concurrently with each other and with
  syncing, so some totals lost or doubled a correction (#2146).

  Runs before syncing starts, so no block updates a total while it's being
  rewritten.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    sums =
      Model.Aex9EventBalance
      |> RocksDbCF.stream()
      |> Enum.reduce(%{}, fn
        Model.aex9_event_balance(index: {contract_pk, account_pk}, amount: amount), sums
        when account_pk != <<>> and is_integer(amount) ->
          Map.update(sums, contract_pk, amount, &(&1 + amount))

        _balance, sums ->
          sums
      end)

    stored_totals =
      Model.Aex9ContractBalance
      |> RocksDbCF.stream()
      |> Map.new(fn Model.aex9_contract_balance(index: contract_pk, amount: amount) ->
        {contract_pk, amount}
      end)

    updated_count =
      stored_totals
      |> Map.new(fn {contract_pk, _amount} -> {contract_pk, 0} end)
      |> Map.merge(sums)
      |> Enum.reject(fn {contract_pk, sum} -> Map.get(stored_totals, contract_pk, 0) == sum end)
      |> Enum.reduce(0, fn {contract_pk, sum}, updated_count ->
        _state =
          State.put(
            state,
            Model.Aex9ContractBalance,
            Model.aex9_contract_balance(index: contract_pk, amount: sum)
          )

        updated_count + 1
      end)

    {:ok, updated_count}
  end
end
