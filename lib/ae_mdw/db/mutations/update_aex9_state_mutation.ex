defmodule AeMdw.Db.UpdateAex9StateMutation do
  @moduledoc """
  Stores the new updated aex9 balances for a contract.
  """

  alias AeMdw.Aex9
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:contract_pk, :txi, :balances]

  @typep aex9_balance() :: {Db.pubkey(), Aex9.amount()}

  @opaque t() :: %__MODULE__{
            contract_pk: Db.pubkey(),
            txi: Txs.txi(),
            balances: [aex9_balance()]
          }

  @spec new(Db.pubkey(), Txs.txi(), [aex9_balance()]) :: t()
  def new(contract_pk, call_txi, balances) do
    %__MODULE__{
      contract_pk: contract_pk,
      txi: call_txi,
      balances: balances
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          contract_pk: contract_pk,
          txi: txi,
          balances: balances
        },
        state
      ) do
    Contract.aex9_init_event_balances(state, contract_pk, balances, txi)
  end
end
