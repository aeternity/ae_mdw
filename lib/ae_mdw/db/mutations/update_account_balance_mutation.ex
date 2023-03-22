defmodule AeMdw.Db.UpdateAccountBalanceMutation do
  @moduledoc """
  Stores latest account balance.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:account_pk, :block_index, :balance]

  @opaque t() :: %__MODULE__{
            account_pk: Db.pubkey(),
            block_index: Blocks.block_index(),
            balance: integer()
          }

  @spec new(Db.pubkey(), Blocks.block_index(), integer()) :: t()
  def new(account_pk, block_index, balance) do
    %__MODULE__{
      account_pk: account_pk,
      block_index: block_index,
      balance: balance
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          account_pk: account_pk,
          block_index: block_index,
          balance: balance
        },
        state
      ) do
    State.put(
      state,
      Model.AccountBalance,
      Model.account_balance(index: account_pk, block_index: block_index, balance: balance)
    )
  end
end
