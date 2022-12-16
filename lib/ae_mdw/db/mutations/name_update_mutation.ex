defmodule AeMdw.Db.NameUpdateMutation do
  @moduledoc """
  Processes name_update_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Names
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [:name_hash, :update_type, :pointers, :txi_idx, :block_index, :internal?]

  @opaque t() :: %__MODULE__{
            name_hash: Names.name_hash(),
            update_type: Name.update_type(),
            pointers: Names.pointers(),
            txi_idx: Txs.txi_idx(),
            block_index: Blocks.block_index()
          }

  @spec new(
          Names.name_hash(),
          Name.update_type(),
          Names.pointers(),
          Txs.txi_idx(),
          Blocks.block_index()
        ) :: t()
  def new(name_hash, update_type, pointers, txi_idx, block_index) do
    %__MODULE__{
      name_hash: name_hash,
      update_type: update_type,
      pointers: pointers,
      txi_idx: txi_idx,
      block_index: block_index
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          name_hash: name_hash,
          update_type: update_type,
          pointers: pointers,
          txi_idx: txi_idx,
          block_index: block_index
        },
        state
      ) do
    Name.update(state, name_hash, update_type, pointers, txi_idx, block_index)
  end
end
