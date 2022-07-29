defmodule AeMdw.Db.PurgeAex9StateMutation do
  @moduledoc """
  Deletes aex9 balances and presence for invalidated balances.
  """

  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:contract_pk, :accounts_pks]

  @opaque t() :: %__MODULE__{
            contract_pk: Db.pubkey(),
            accounts_pks: [Db.pubkey()]
          }

  @spec new(Db.pubkey(), [Db.pubkey()]) :: t()
  def new(contract_pk, accounts_pks) do
    %__MODULE__{
      contract_pk: contract_pk,
      accounts_pks: accounts_pks
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          contract_pk: contract_pk,
          accounts_pks: accounts_pks
        },
        state
      ) do
    Enum.reduce(accounts_pks, state, fn account_pk, state ->
      state
      |> Contract.aex9_delete_presence(account_pk, contract_pk)
      |> safe_delete_balance(contract_pk, account_pk)
    end)
  end

  defp safe_delete_balance(state, contract_pk, account_pk) do
    if State.exists?(state, Model.Aex9Balance, {contract_pk, account_pk}) do
      State.delete(state, Model.Aex9Balance, {contract_pk, account_pk})
    else
      state
    end
  end
end
