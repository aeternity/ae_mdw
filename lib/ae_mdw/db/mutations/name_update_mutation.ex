defmodule AeMdw.Db.NameUpdateMutation do
  @moduledoc """
  Processes name_update_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Names
  alias AeMdw.Txs

  defstruct [:name_hash, :name_ttl, :pointers, :txi, :block_index]

  @opaque t() :: %__MODULE__{
            name_hash: Names.name_hash(),
            name_ttl: Names.ttl(),
            pointers: Names.pointers(),
            txi: Txs.txi(),
            block_index: Blocks.block_index()
          }

  @spec new(Names.name_hash(), Names.ttl(), Names.pointers(), Txs.txi(), Blocks.block_index()) ::
          t()
  def new(name_hash, name_ttl, pointers, txi, block_index) do
    %__MODULE__{
      name_hash: name_hash,
      name_ttl: name_ttl,
      pointers: pointers,
      txi: txi,
      block_index: block_index
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        name_hash: name_hash,
        name_ttl: name_ttl,
        pointers: pointers,
        txi: txi,
        block_index: block_index
      }) do
    Name.update(name_hash, name_ttl, pointers, txi, block_index)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.NameUpdateMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
