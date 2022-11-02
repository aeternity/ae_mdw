defmodule AeMdw.Db.UpdateAex9StateMutation do
  @moduledoc """
  Stores the new updated aex9 balances for a contract.
  """

  alias AeMdw.Aex9
  alias AeMdw.Blocks
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:contract_pk, :block_index, :txi, :balances]

  @typep aex9_balance() :: {Db.pubkey(), Aex9.amount()}

  @opaque t() :: %__MODULE__{
            contract_pk: Db.pubkey(),
            block_index: Blocks.block_index(),
            txi: Txs.txi(),
            balances: [aex9_balance()]
          }

  @spec new(Db.pubkey(), Blocks.block_index(), Txs.txi(), [aex9_balance()]) :: t()
  def new(contract_pk, block_index, call_txi, balances) do
    %__MODULE__{
      contract_pk: contract_pk,
      block_index: block_index,
      txi: call_txi,
      balances: balances
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          contract_pk: contract_pk,
          block_index: block_index,
          txi: txi,
          balances: balances
        },
        state
      ) do
    Contract.aex9_write_balances(state, contract_pk, balances, block_index, txi)
  end
end
