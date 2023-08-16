defmodule AeMdw.Db.NameTransferMutation do
  @moduledoc """
  Processes name_transfer_tx.
  """

  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Names
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [:name_hash, :new_owner, :txi_idx]

  @opaque t() :: %__MODULE__{
            name_hash: Names.name_hash(),
            new_owner: Db.pubkey(),
            txi_idx: Txs.txi_idx()
          }

  @spec new(Node.tx(), Txs.txi_idx()) :: t()
  def new(tx, txi_idx) do
    name_hash = :aens_transfer_tx.name_hash(tx)
    new_owner = :aens_transfer_tx.recipient_pubkey(tx)

    %__MODULE__{
      name_hash: name_hash,
      new_owner: new_owner,
      txi_idx: txi_idx
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          name_hash: name_hash,
          new_owner: new_owner,
          txi_idx: txi_idx
        },
        state
      ) do
    Name.transfer(state, name_hash, new_owner, txi_idx)
  end
end
