defmodule AeMdw.Db.Sync.Transaction do
  @moduledoc "
  Syncs whole history based on Node events (and assumes block index is in place.
  "

  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.ContractCreateMutation
  alias AeMdw.Db.ContractCreateCacheMutation
  alias AeMdw.Db.IncreaseTypeCountMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.NameRevokeMutation
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.OracleExtendMutation
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Db.Sync.Contract, as: SyncContract
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Db.Sync.Name, as: SyncName
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Db.WriteFieldsMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Mutation
  alias AeMdw.Node
  alias AeMdw.Txs
  alias __MODULE__.TxContext

  require Model

  defmodule TxContext do
    @moduledoc """
    Transaction context struct that contains necessary information to build a transaction mutation.
    """

    defstruct [:type, :tx, :signed_tx, :txi, :tx_hash, :block_index, :block_hash, :tx_events]

    @type t() :: %__MODULE__{
            type: Node.tx_type(),
            tx: Node.tx(),
            signed_tx: Node.signed_tx(),
            txi: Txs.txi(),
            tx_hash: Txs.tx_hash(),
            block_index: Blocks.block_index(),
            block_hash: Blocks.block_hash(),
            tx_events: [Contract.event()]
          }
  end

  @spec transaction_mutations(
          Node.signed_tx(),
          Txs.txi(),
          {Blocks.block_index(), Blocks.block_hash(), Blocks.time(), Contract.grouped_events()},
          boolean()
        ) :: [Mutation.t()]
  def transaction_mutations(
        signed_tx,
        txi,
        {block_index, block_hash, mb_time, mb_events} = tx_ctx,
        inner_tx? \\ false
      ) do
    {mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    tx_hash = :aetx_sign.hash(signed_tx)
    type = mod.type()

    tx_context = %TxContext{
      type: type,
      tx: tx,
      signed_tx: signed_tx,
      txi: txi,
      tx_hash: tx_hash,
      block_index: block_index,
      block_hash: block_hash,
      tx_events: Map.get(mb_events, tx_hash, [])
    }

    inner_txn_mutations =
      if type == :ga_meta_tx or type == :paying_for_tx do
        inner_signed_tx = InnerTx.signed_tx(type, tx)
        # indexes the inner with the txi from the wrapper/outer
        transaction_mutations(inner_signed_tx, txi, tx_ctx, true)
      end

    m_tx = Model.tx(index: txi, id: tx_hash, block_index: block_index, time: mb_time)
    :ets.insert(:tx_sync_cache, {txi, m_tx})

    m_tx_mutation =
      if not inner_tx? do
        WriteMutation.new(Model.Tx, m_tx)
      end

    [
      m_tx_mutation,
      WriteMutation.new(Model.Type, Model.type(index: {type, txi})),
      IncreaseTypeCountMutation.new(type),
      WriteMutation.new(Model.Time, Model.time(index: {mb_time, txi})),
      WriteFieldsMutation.new(type, tx, block_index, txi),
      tx_mutations(tx_context),
      inner_txn_mutations
    ]
  end

  defp tx_mutations(%TxContext{
         type: :contract_create_tx,
         tx: tx,
         txi: txi,
         tx_hash: tx_hash,
         block_index: block_index,
         block_hash: block_hash,
         tx_events: tx_events
       }) do
    contract_pk = :aect_create_tx.contract_pubkey(tx)

    mutations = Origin.origin_mutations(:contract_create_tx, nil, contract_pk, txi, tx_hash)

    if Contract.is_contract?(contract_pk) do
      call_rec = Contract.get_init_call_rec(tx, block_hash)

      events_mutations =
        SyncContract.events_mutations(
          tx_events,
          block_index,
          block_hash,
          txi,
          tx_hash,
          contract_pk
        )

      aexn_create_contract_mutation =
        if :ok == :aect_call.return_type(call_rec) do
          SyncContract.aexn_create_contract_mutation(contract_pk, block_index, txi)
        end

      Enum.concat([
        mutations,
        events_mutations,
        [
          aexn_create_contract_mutation,
          ContractCreateMutation.new(block_index, txi, call_rec)
        ]
      ])
    else
      mutations
    end
  end

  defp tx_mutations(%TxContext{
         type: :contract_call_tx,
         tx: tx,
         txi: txi,
         block_index: block_index,
         block_hash: block_hash,
         tx_events: tx_events,
         tx_hash: tx_hash
       }) do
    contract_pk = :aect_call_tx.contract_pubkey(tx)

    {fun_arg_res, call_rec} = Contract.call_tx_info(tx, contract_pk, block_hash)

    child_mutations =
      if :aect_call.return_type(call_rec) == :ok do
        SyncContract.child_contract_mutations(
          fun_arg_res,
          block_index,
          txi,
          tx_hash
        )
      else
        []
      end

    events_mutations =
      SyncContract.events_mutations(
        tx_events,
        block_index,
        block_hash,
        txi,
        tx_hash,
        contract_pk
      )

    Enum.concat([
      child_mutations,
      events_mutations,
      [
        ContractCallMutation.new(
          contract_pk,
          block_index,
          txi,
          fun_arg_res,
          call_rec
        )
      ]
    ])
  end

  defp tx_mutations(%TxContext{
         type: :channel_create_tx,
         signed_tx: signed_tx,
         txi: txi,
         tx_hash: tx_hash
       }) do
    {:ok, channel_pk} = :aesc_utils.channel_pubkey(signed_tx)

    Origin.origin_mutations(:channel_create_tx, nil, channel_pk, txi, tx_hash)
  end

  defp tx_mutations(%TxContext{type: :ga_attach_tx, tx: tx, txi: txi, tx_hash: tx_hash}) do
    contract_pk = :aega_attach_tx.contract_pubkey(tx)

    [
      Origin.origin_mutations(:ga_attach_tx, nil, contract_pk, txi, tx_hash),
      ContractCreateCacheMutation.new(contract_pk, txi)
    ]
  end

  defp tx_mutations(%TxContext{
         type: :oracle_register_tx,
         tx: tx,
         txi: txi,
         tx_hash: tx_hash,
         block_index: {height, _mbi} = block_index
       }) do
    oracle_pk = :aeo_register_tx.account_pubkey(tx)
    delta_ttl = :aeo_utils.ttl_delta(height, :aeo_register_tx.oracle_ttl(tx))
    expire = height + delta_ttl

    [
      Origin.origin_mutations(:oracle_register_tx, nil, oracle_pk, txi, tx_hash),
      OracleRegisterMutation.new(oracle_pk, block_index, expire, txi)
    ]
  end

  defp tx_mutations(%TxContext{
         type: :name_claim_tx,
         tx: tx,
         txi: txi,
         tx_hash: tx_hash,
         block_index: block_index
       }) do
    SyncName.name_claim_mutations(tx, tx_hash, block_index, txi)
  end

  defp tx_mutations(%TxContext{
         type: :oracle_extend_tx,
         tx: tx,
         txi: txi,
         block_index: block_index
       }) do
    oracle_pk = :aeo_extend_tx.oracle_pubkey(tx)
    {:delta, delta_ttl} = :aeo_extend_tx.oracle_ttl(tx)

    [
      OracleExtendMutation.new(block_index, txi, oracle_pk, delta_ttl)
    ]
  end

  defp tx_mutations(%TxContext{
         type: :oracle_response_tx,
         tx: tx,
         txi: txi,
         block_hash: block_hash,
         block_index: block_index
       }) do
    [
      Oracle.response_mutation(tx, block_index, block_hash, txi)
    ]
  end

  defp tx_mutations(%TxContext{
         type: :name_update_tx,
         tx: tx,
         txi: txi,
         block_index: block_index
       }) do
    [
      NameUpdateMutation.new(tx, txi, block_index)
    ]
  end

  defp tx_mutations(%TxContext{
         type: :name_transfer_tx,
         tx: tx,
         txi: txi,
         block_index: block_index
       }) do
    [
      NameTransferMutation.new(tx, txi, block_index)
    ]
  end

  defp tx_mutations(%TxContext{
         type: :name_revoke_tx,
         tx: tx,
         txi: txi,
         block_index: block_index
       }) do
    name_hash = :aens_revoke_tx.name_hash(tx)

    [
      NameRevokeMutation.new(name_hash, txi, block_index)
    ]
  end

  defp tx_mutations(_tx_context), do: []
end
