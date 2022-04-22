defmodule AeMdw.Db.NameRevokeMutation do
  @moduledoc """
  Processes name_revoke_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Names
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [:name_hash, :txi, :block_index]

  @opaque t() :: %__MODULE__{
            name_hash: Names.name_hash(),
            txi: Txs.txi(),
            block_index: Blocks.block_index()
          }

  @spec new(Names.name_hash(), Txs.txi(), Blocks.block_index()) :: t()
  def new(name_hash, txi, block_index) do
    %__MODULE__{
      name_hash: name_hash,
      txi: txi,
      block_index: block_index
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{name_hash: name_hash, txi: txi, block_index: block_index}, state) do
    Name.revoke(state, name_hash, txi, block_index)
  end
end
