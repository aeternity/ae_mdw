defmodule AeMdw.Db.NameTransferMutation do
  @moduledoc """
  Processes name_transfer_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Names
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  defstruct [:name_hash, :new_owner, :txi, :block_index]

  @opaque t() :: %__MODULE__{
            name_hash: Names.name_hash(),
            new_owner: Db.pubkey(),
            txi: Txs.txi(),
            block_index: Blocks.block_index()
          }

  @spec new(Node.tx(), Txs.txi(), Blocks.block_index()) :: t()
  def new(tx, txi, block_index) do
    name_hash = :aens_transfer_tx.name_hash(tx)
    new_owner = :aens_transfer_tx.recipient_pubkey(tx)

    %__MODULE__{
      name_hash: name_hash,
      new_owner: new_owner,
      txi: txi,
      block_index: block_index
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        name_hash: name_hash,
        new_owner: new_owner,
        txi: txi,
        block_index: block_index
      }) do
    Name.transfer(name_hash, new_owner, txi, block_index)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.NameTransferMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
