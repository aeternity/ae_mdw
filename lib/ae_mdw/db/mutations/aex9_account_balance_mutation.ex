defmodule AeMdw.Db.Aex9AccountBalanceMutation do
  @moduledoc """
  Computes and derives Aex9 tokens, and stores it into the appropriate indexes.
  """

  alias AeMdw.Contract
  alias AeMdw.Database
  alias AeMdw.Db.Contract, as: DbContract
  alias AeMdw.Node.Db

  @derive AeMdw.Db.TxnMutation
  defstruct [:method_name, :method_args, :contract_pk, :caller_pk]

  @opaque t() :: %__MODULE__{
            method_name: Contract.method_name(),
            method_args: Contract.method_args(),
            contract_pk: Db.pubkey(),
            caller_pk: Db.pubkey()
          }

  @spec new(Contract.method_name(), Contract.method_args(), Db.pubkey(), Db.pubkey()) :: t()
  def new(method_name, method_args, contract_pk, caller_pk) do
    %__MODULE__{
      method_name: method_name,
      method_args: method_args,
      contract_pk: contract_pk,
      caller_pk: caller_pk
    }
  end

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(
        %__MODULE__{
          method_name: method_name,
          method_args: method_args,
          contract_pk: contract_pk,
          caller_pk: caller_pk
        },
        txn
      ) do
    update_aex9_balance(txn, method_name, method_args, contract_pk, caller_pk)
    :ok
  end

  defp update_aex9_balance(
         txn,
         "burn",
         [%{type: :int, value: value}],
         contract_pk,
         account_pk
       ) do
    DbContract.aex9_burn_balance(txn, contract_pk, account_pk, value)
  end

  defp update_aex9_balance(txn, "swap", [], contract_pk, caller_pk) do
    DbContract.aex9_swap_balance(txn, contract_pk, caller_pk)
  end

  defp update_aex9_balance(
         txn,
         "mint",
         [
           %{type: :address, value: to_pk},
           %{type: :int, value: value}
         ],
         contract_pk,
         _caller_pk
       ) do
    DbContract.aex9_mint_balance(txn, contract_pk, to_pk, value)
  end

  defp update_aex9_balance(txn, method_name, method_args, contract_pk, caller_pk) do
    case Contract.get_aex9_transfer(caller_pk, method_name, method_args) do
      {from_pk, to_pk, value} ->
        DbContract.aex9_transfer_balance(txn, contract_pk, from_pk, to_pk, value)

      nil ->
        DbContract.aex9_delete_balances(txn, contract_pk)
    end
  end
end
