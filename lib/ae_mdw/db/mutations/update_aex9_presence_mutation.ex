defmodule AeMdw.Db.UpdateAex9PresenceMutation do
  @moduledoc """
  Stores the new updated aex9 balances for a contract.
  """

  alias AeMdw.Aex9
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:contract_pk, :balances]

  @typep aex9_balance() :: {Db.pubkey(), Aex9.amount()}

  @opaque t() :: %__MODULE__{
            contract_pk: Db.pubkey(),
            balances: [aex9_balance()]
          }

  @spec new(Db.pubkey(), [aex9_balance()]) :: t()
  def new(contract_pk, balances) do
    %__MODULE__{
      balances: balances,
      contract_pk: contract_pk
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          contract_pk: contract_pk,
          balances: balances
        },
        state
      ) do
    create_txi = Origin.tx_index!(state, {:contract, contract_pk})

    Enum.reduce(balances, state, fn {account_pk, amount}, state ->
      m_balance =
        Model.aex9_balance(
          index: {contract_pk, account_pk},
          amount: amount
        )

      {_exists?, state2} =
        Contract.aex9_write_new_presence(state, contract_pk, create_txi, account_pk)

      State.put(state2, Model.Aex9Balance, m_balance)
    end)
  end
end
