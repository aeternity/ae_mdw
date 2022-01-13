defmodule AeMdw.Db.WriteLinksMutation do
  @moduledoc """
  Creates all the necessary indexes for both Oracles and Names depending on the
  transaction type.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync
  alias AeMdw.Node
  alias AeMdw.Txs

  require Model

  defstruct [:type, :tx, :signed_tx, :txi, :tx_hash, :block_index, :block_hash]

  @opaque t() :: %__MODULE__{
            type: Node.tx_type(),
            tx: Model.tx(),
            signed_tx: Node.signed_tx(),
            txi: Txs.txi(),
            tx_hash: Txs.tx_hash(),
            block_index: Blocks.block_index(),
            block_hash: Blocks.block_hash()
          }

  @spec new(
          Node.tx_type(),
          Model.tx(),
          Node.signed_tx(),
          Txs.txi(),
          Txs.tx_hash(),
          Blocks.block_index(),
          Blocks.block_hash()
        ) :: t()
  def new(type, tx, signed_tx, txi, tx_hash, block_index, block_hash) do
    %__MODULE__{
      type: type,
      tx: tx,
      signed_tx: signed_tx,
      txi: txi,
      tx_hash: tx_hash,
      block_index: block_index,
      block_hash: block_hash
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{type: :contract_create_tx}) do
    :ok
  end

  def mutate(%__MODULE__{type: :ga_attach_tx}), do: :ok

  def mutate(%__MODULE__{type: :contract_call_tx}) do
    :ok
  end

  def mutate(%__MODULE__{type: :channel_create_tx}) do
    :ok
  end

  def mutate(%__MODULE__{type: :oracle_register_tx}) do
    :ok
  end

  def mutate(%__MODULE__{type: :oracle_extend_tx}) do
    :ok
  end

  def mutate(%__MODULE__{type: :oracle_response_tx}) do
    :ok
  end

  def mutate(%__MODULE__{type: :name_claim_tx}) do
    :ok
  end

  def mutate(%__MODULE__{type: :name_update_tx, tx: tx, txi: txi, block_index: block_index}) do
    Sync.Name.update(:aens_update_tx.name_hash(tx), tx, txi, block_index)
  end

  def mutate(%__MODULE__{type: :name_transfer_tx, tx: tx, txi: txi, block_index: block_index}) do
    Sync.Name.transfer(:aens_transfer_tx.name_hash(tx), tx, txi, block_index)
  end

  def mutate(%__MODULE__{type: :name_revoke_tx, tx: tx, txi: txi, block_index: block_index}) do
    Sync.Name.revoke(:aens_revoke_tx.name_hash(tx), tx, txi, block_index)
  end

  def mutate(_write_links_mutation) do
    :ok
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.WriteLinksMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
