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

  defstruct [:type, :tx, :signed_tx, :txi, :tx_hash, :block_index]

  @opaque t() :: %__MODULE__{
            type: Node.tx_type(),
            tx: Model.tx(),
            signed_tx: Node.signed_tx(),
            txi: Txs.txi(),
            tx_hash: Txs.tx_hash(),
            block_index: Blocks.block_index()
          }

  @spec new(
          Node.tx_type(),
          Model.tx(),
          Node.signed_tx(),
          Txs.txi(),
          Txs.tx_hash(),
          Blocks.block_index()
        ) :: t()
  def new(type, tx, signed_tx, txi, tx_hash, block_index) do
    %__MODULE__{
      type: type,
      tx: tx,
      signed_tx: signed_tx,
      txi: txi,
      tx_hash: tx_hash,
      block_index: block_index
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        type: :contract_create_tx,
        tx: tx,
        txi: txi,
        tx_hash: tx_hash,
        block_index: block_index
      }) do
    pk = :aect_contracts.pubkey(:aect_contracts.new(tx))
    owner_pk = :aect_create_tx.owner_pubkey(tx)
    :ets.insert(:ct_create_sync_cache, {pk, txi})
    write_origin(:contract_create_tx, pk, txi, tx_hash)
    Sync.Contract.create(pk, owner_pk, txi, block_index)
  end

  def mutate(%__MODULE__{type: :contract_call_tx, tx: tx, txi: txi, block_index: block_index}) do
    pk = :aect_call_tx.contract_pubkey(tx)
    Sync.Contract.call(pk, tx, txi, block_index)
  end

  def mutate(%__MODULE__{
        type: :channel_create_tx,
        signed_tx: signed_tx,
        txi: txi,
        tx_hash: tx_hash
      }) do
    {:ok, pk} = :aesc_utils.channel_pubkey(signed_tx)
    write_origin(:channel_create_tx, pk, txi, tx_hash)
  end

  def mutate(%__MODULE__{
        type: :oracle_register_tx,
        tx: tx,
        txi: txi,
        tx_hash: tx_hash,
        block_index: block_index
      }) do
    pk = :aeo_register_tx.account_pubkey(tx)
    write_origin(:oracle_register_tx, pk, txi, tx_hash)
    Sync.Oracle.register(pk, tx, txi, block_index)
  end

  def mutate(%__MODULE__{type: :oracle_extend_tx, tx: tx, txi: txi, block_index: block_index}) do
    Sync.Oracle.extend(:aeo_extend_tx.oracle_pubkey(tx), tx, txi, block_index)
  end

  def mutate(%__MODULE__{type: :oracle_response_tx, tx: tx, txi: txi, block_index: block_index}) do
    Sync.Oracle.respond(:aeo_response_tx.oracle_pubkey(tx), tx, txi, block_index)
  end

  def mutate(%__MODULE__{
        type: :name_claim_tx,
        tx: tx,
        txi: txi,
        tx_hash: tx_hash,
        block_index: block_index
      }) do
    plain_name = String.downcase(:aens_claim_tx.name(tx))
    {:ok, name_hash} = :aens.get_name_hash(plain_name)
    write_origin(:name_claim_tx, name_hash, txi, tx_hash)
    Sync.Name.claim(plain_name, name_hash, tx, txi, block_index)
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

  defp write_origin(tx_type, pubkey, txi, tx_hash) do
    m_origin = Model.origin(index: {tx_type, pubkey, txi}, tx_id: tx_hash)
    m_rev_origin = Model.rev_origin(index: {txi, tx_type, pubkey})
    :mnesia.write(Model.Origin, m_origin, :write)
    :mnesia.write(Model.RevOrigin, m_rev_origin, :write)
    write_field(tx_type, nil, pubkey, txi)
  end

  defp write_field(tx_type, pos, pubkey, txi) do
    m_field = Model.field(index: {tx_type, pos, pubkey, txi})
    :mnesia.write(Model.Field, m_field, :write)
    Model.incr_count({tx_type, pos, pubkey})
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.WriteLinksMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
