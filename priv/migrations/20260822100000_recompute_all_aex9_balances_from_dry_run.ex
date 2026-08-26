defmodule AeMdw.Migrations.RecomputeAllAex9BalancesFromDryRun do
  @moduledoc """
  Re-derives (via dry-run) the balances of every AEX-9 contract, superseding
  the narrower FixAex9NestedCreationDoubleCountedBalances migration now that
  balance tracking always trusts a dry-run over per-event arithmetic (#2155,
  #2156). Any historical drift accumulated by the old incremental
  mint/burn/swap/transfer bookkeeping - not just the nested-creation case -
  is corrected by this migration. Aex9InitialSupply is left untouched since a
  dry-run only gives the contract's current total, not its true value at
  creation.

  Each affected contract needs a real dry-run call, so when started from the
  application (from_start? = true) the work is pushed to a supervised task
  and the API becomes available immediately.
  """

  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Sync.Aex9Balances

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()} | {:async, [fun()]}
  def run(state, true = _from_start?) do
    {:async, [fn -> do_run(state) end]}
  end

  def run(state, _from_start?) do
    {:ok, do_run(state)}
  end

  defp do_run(state) do
    block_index = {State.height(state), -1}

    Model.AexnContract
    |> RocksDbCF.stream()
    |> Stream.filter(fn Model.aexn_contract(index: {aexn_type, _pk}) -> aexn_type == :aex9 end)
    |> Stream.map(fn Model.aexn_contract(
                       index: {_aexn_type, contract_pk},
                       txi_idx: {txi, _idx}
                     ) ->
      case Aex9Balances.get_balances(contract_pk, block_index) do
        {:ok, balances, _purge} ->
          update_balances(state, contract_pk, balances, txi)
          1

        {:error, _reason} ->
          0
      end
    end)
    |> Enum.sum()
  end

  defp update_balances(state, contract_pk, balances, txi) do
    Enum.each(balances, fn {account_pk, new_amount} ->
      old_amount =
        case State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk}) do
          :not_found -> 0
          {:ok, Model.aex9_event_balance(amount: amount)} -> amount
        end

      m_balance =
        Model.aex9_event_balance(
          index: {contract_pk, account_pk},
          txi: txi,
          log_idx: -1,
          amount: new_amount
        )

      _state =
        state
        |> State.put(Model.Aex9EventBalance, m_balance)
        |> update_balance_account(
          contract_pk,
          old_amount,
          new_amount,
          account_pk,
          txi,
          -1
        )
        |> Contract.aex9_write_presence(contract_pk, txi, account_pk)
        |> Contract.aex9_update_holders_to_balance_change(
          contract_pk,
          old_amount,
          new_amount,
          txi
        )
        |> update_contract_balance(contract_pk, new_amount - old_amount)
    end)
  end

  # mirrors the private AeMdw.Db.Contract helper of the same purpose
  defp update_balance_account(
         state,
         contract_pk,
         old_amount,
         new_amount,
         account_pk,
         txi,
         log_idx
       ) do
    m_balance_account =
      Model.aex9_balance_account(
        index: {contract_pk, new_amount, account_pk},
        txi: txi,
        log_idx: log_idx
      )

    state =
      if State.exists?(state, Model.Aex9BalanceAccount, {contract_pk, old_amount, account_pk}) do
        State.delete(state, Model.Aex9BalanceAccount, {contract_pk, old_amount, account_pk})
      else
        state
      end

    State.put(state, Model.Aex9BalanceAccount, m_balance_account)
  end

  defp update_contract_balance(state, contract_pk, delta_amount) do
    State.update(
      state,
      Model.Aex9ContractBalance,
      contract_pk,
      fn Model.aex9_contract_balance(amount: amount) = m_bal ->
        Model.aex9_contract_balance(m_bal, amount: amount + delta_amount)
      end,
      Model.aex9_contract_balance(index: contract_pk, amount: 0)
    )
  end
end
