defmodule AeMdw.Db.Sync.Transaction do
  @moduledoc "
  Syncs whole history based on Node events (and assumes block index is in place.
  "

  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Aex9AccountBalanceMutation
  alias AeMdw.Db.Aex9CreateContractMutation
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.ContractCreateMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.NameRevokeMutation
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Db.NamesExpirationMutation
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.OracleExtendMutation
  alias AeMdw.Db.OraclesExpirationMutation
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Db.Sync.Contract, as: SyncContract
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Db.Sync.Name, as: SyncName
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Db.WriteFieldsMutation
  alias AeMdw.Db.WriteTxnMutation
  alias AeMdw.Db.TxnMutation
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
        ) :: [TxnMutation.t()]
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
        WriteTxnMutation.new(Model.Tx, m_tx)
      end

    [
      m_tx_mutation,
      WriteTxnMutation.new(Model.Type, Model.type(index: {type, txi})),
      WriteTxnMutation.new(Model.Time, Model.time(index: {mb_time, txi})),
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
    owner_pk = :aect_create_tx.owner_pubkey(tx)

    :ets.insert(:ct_create_sync_cache, {contract_pk, txi})

    mutations = Origin.origin_mutations(:contract_create_tx, nil, contract_pk, txi, tx_hash)

    case Contract.get_info(contract_pk) do
      {:ok, {type_info, _compiler_vsn, _source_hash}} ->
        call_rec = Contract.get_init_call_rec(tx, block_hash)

        aex9_create_contract_mutation =
          with :ok <- :aect_call.return_type(call_rec),
               true <- Contract.is_aex9?(type_info),
               {:ok, aex9_meta_info} <- Contract.aex9_meta_info(contract_pk) do
            Aex9CreateContractMutation.new(
              contract_pk,
              aex9_meta_info,
              owner_pk,
              block_index,
              txi
            )
          else
            _failed -> nil
          end

        mutations ++
          SyncContract.events_mutations(tx_events, block_index, block_hash, txi, tx_hash, txi) ++
          [
            aex9_create_contract_mutation,
            ContractCreateMutation.new(txi, call_rec)
          ]

      {:error, _reason} ->
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
    <<caller_pk::binary-32>> = :aect_call_tx.caller_pubkey(tx)
    create_txi = SyncContract.get_txi!(contract_pk)

    {fun_arg_res, call_rec} =
      Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)

    child_mutations =
      if :aect_call.return_type(call_rec) == :ok do
        SyncContract.child_contract_mutations(
          fun_arg_res,
          caller_pk,
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
        create_txi
      )

    aex9_balance_mutation =
      with :ok <- :aect_call.return_type(call_rec),
           true <- Contract.is_aex9?(contract_pk),
           {:ok, method_name, method_args} <- Contract.extract_successful_function(fun_arg_res) do
        Aex9AccountBalanceMutation.new(method_name, method_args, contract_pk, caller_pk)
      else
        _error_or_false -> nil
      end

    Enum.concat([
      child_mutations,
      events_mutations,
      [
        aex9_balance_mutation,
        ContractCallMutation.new(
          contract_pk,
          caller_pk,
          create_txi,
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
    :ets.insert(:ct_create_sync_cache, {contract_pk, txi})
    AeMdw.Ets.inc(:stat_sync_cache, :contracts_created)

    Origin.origin_mutations(:ga_attach_tx, nil, contract_pk, txi, tx_hash)
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
