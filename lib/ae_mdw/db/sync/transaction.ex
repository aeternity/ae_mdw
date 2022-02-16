defmodule AeMdw.Db.Sync.Transaction do
  @moduledoc "
  Syncs whole history based on Node events (and assumes block index is in place.
  "

  alias AeMdw.Blocks
  alias AeMdw.Node, as: AE
  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync
  alias AeMdw.Db.Aex9AccountPresenceMutation
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.ContractCreateMutation
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.KeyBlocksMutation
  alias AeMdw.Db.DatabaseWriteMutation
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Name
  alias AeMdw.Db.NameRevokeMutation
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.OracleExtendMutation
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Db.WriteFieldsMutation
  alias AeMdw.Db.WriteTxMutation
  alias AeMdw.Database
  alias AeMdw.Node
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Txs
  alias AeMdwWeb.Websocket.Broadcaster
  alias __MODULE__.TxContext

  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

  @log_freq 1000
  @sync_cache_cleanup_freq 150_000

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

  ################################################################################

  @spec sync(non_neg_integer() | :safe) :: pos_integer()
  def sync(max_height \\ :safe) do
    max_height = Sync.height((is_integer(max_height) && max_height + 1) || max_height)
    bi_max_kbi = Sync.BlockIndex.sync(max_height) - 1

    case Database.last_key(Model.Tx) do
      :none ->
        sync(0, bi_max_kbi, 0)

      {:ok, max_txi} when is_integer(max_txi) ->
        # sync same height again to resume from previous microblock
        {from_height, _} = Model.tx(read_tx!(max_txi), :block_index)
        next_txi = max_txi + 1
        sync(from_height, bi_max_kbi, next_txi)
    end
  end

  @spec sync(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: pos_integer()
  def sync(from_height, to_height, txi) when from_height <= to_height do
    tracker = Sync.progress_logger(&sync_generation/2, @log_freq, &log_msg/2)
    next_txi = Enum.reduce(from_height..to_height, txi, tracker)

    next_txi
  end

  def sync(from_height, to_height, txi) when from_height > to_height,
    do: txi

  @spec transaction_mutations(
          {Node.signed_tx(), Txs.txi()},
          {Blocks.block_index(), Blocks.block_hash(), Blocks.time(), Contract.grouped_events()},
          boolean()
        ) :: [Mutation.t()]
  def transaction_mutations(
        {signed_tx, txi},
        {block_index, block_hash, mb_time, mb_events} = tx_ctx,
        inner_tx? \\ false
      ) do
    {mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    tx_hash = :aetx_sign.hash(signed_tx)
    type = mod.type()
    model_tx = Model.tx(index: txi, id: tx_hash, block_index: block_index, time: mb_time)

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

    inner_tx_mutations =
      if type == :ga_meta_tx or type == :paying_for_tx do
        inner_signed_tx = Sync.InnerTx.signed_tx(type, tx)
        # indexes the inner with the txi from the wrapper/outer
        transaction_mutations({inner_signed_tx, txi}, tx_ctx, true)
      end

    :ets.insert(:tx_sync_cache, {txi, model_tx})

    [
      WriteTxMutation.new(model_tx, type, txi, mb_time, inner_tx?),
      tx_mutations(tx_context),
      WriteFieldsMutation.new(type, tx, block_index, txi),
      inner_tx_mutations
    ]
    |> List.flatten()
  end

  ################################################################################

  defp sync_generation(height, txi) do
    gen_fully_synced? =
      case Database.read(Model.Block, {height + 1, -1}) do
        [] -> false
        [Model.block(tx_index: next_txi)] -> not is_nil(next_txi)
      end

    if gen_fully_synced? do
      txi
    else
      _next_txi = do_sync_generation(height, txi)
    end
  end

  defp do_sync_generation(height, txi) do
    {key_block, micro_blocks} = AE.Db.get_blocks(height)
    kb_txi = (txi == 0 && -1) || txi
    kb_header = :aec_blocks.to_key_header(key_block)
    kb_hash = ok!(:aec_headers.hash_header(kb_header))

    :ets.delete_all_objects(:stat_sync_cache)
    :ets.delete_all_objects(:ct_create_sync_cache)
    :ets.delete_all_objects(:tx_sync_cache)

    last_mbi =
      case Database.prev_key(Model.Block, {height + 1, -1}) do
        {:ok, {^height, last_mbi}} -> last_mbi
        {:ok, _other_height} -> -1
        :none -> -1
      end

    {next_txi, _mb_index} =
      Enum.reduce(micro_blocks, {txi, 0}, fn mblock, {txi, mbi} = txi_acc ->
        if mbi > last_mbi do
          {mutations, acc} = micro_block_mutations(mblock, txi_acc)
          Database.transaction(mutations)
          Database.commit()
          Producer.commit_enqueued()
          Broadcaster.broadcast_micro_block(mblock, :mdw)
          Broadcaster.broadcast_txs(mblock, :mdw)
          acc
        else
          {txi, mbi + 1}
        end
      end)

    kb_model = Model.block(index: {height, -1}, tx_index: kb_txi, hash: kb_hash)

    expirations_mutations = [
      Name.expirations_mutation(height),
      Oracle.expirations_mutation(height - 1)
    ]

    if height >= AE.min_block_reward_height() do
      Database.transaction([
        IntTransfer.block_rewards_mutation(height, kb_header, kb_hash)
        | expirations_mutations
      ])
    else
      Database.transaction(expirations_mutations)
    end

    Database.transaction([
      Stats.new_mutation(height, last_mbi == -1),
      KeyBlocksMutation.new(kb_model, next_txi)
    ])

    Database.commit()

    Broadcaster.broadcast_key_block(key_block, :mdw)

    if rem(height, @sync_cache_cleanup_freq) == 0 do
      :ets.delete_all_objects(:name_sync_cache)
      :ets.delete_all_objects(:oracle_sync_cache)
    end

    next_txi
  end

  defp micro_block_mutations(mblock, {txi, mbi}) do
    height = :aec_blocks.height(mblock)
    mb_time = :aec_blocks.time_in_msecs(mblock)
    mb_hash = ok!(:aec_headers.hash_header(:aec_blocks.to_micro_header(mblock)))
    mb_txi = (txi == 0 && -1) || txi
    mb_model = Model.block(index: {height, mbi}, tx_index: mb_txi, hash: mb_hash)
    mb_txs = :aec_blocks.txs(mblock)
    events = AeMdw.Contract.get_grouped_events(mblock)
    tx_ctx = {{height, mbi}, mb_hash, mb_time, events}

    txs_mutations =
      mb_txs
      |> Enum.with_index(txi)
      |> Enum.flat_map(&transaction_mutations(&1, tx_ctx))

    mutations = [
      DatabaseWriteMutation.new(Model.Block, mb_model),
      txs_mutations,
      Aex9AccountPresenceMutation.new(height, mbi)
    ]

    {mutations, {txi + length(mb_txs), mbi + 1}}
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

        aex9_meta_info =
          with :ok <- :aect_call.return_type(call_rec),
               true <- Contract.is_aex9?(type_info),
               {:ok, meta_info} <- Contract.aex9_meta_info(contract_pk) do
            meta_info
          else
            _failed -> nil
          end

        mutations ++
          Sync.Contract.events_mutations(tx_events, block_index, block_hash, txi, tx_hash, txi) ++
          [
            ContractCreateMutation.new(contract_pk, txi, owner_pk, aex9_meta_info, call_rec)
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
    create_txi = Sync.Contract.get_txi!(contract_pk)

    {fun_arg_res, call_rec} =
      Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)

    {child_mutations, aex9_meta_info} =
      Sync.Contract.child_contract_mutations(
        :aect_call.return_type(call_rec) == :ok,
        fun_arg_res,
        txi,
        tx_hash
      )

    child_mutations ++
      Sync.Contract.events_mutations(tx_events, block_index, block_hash, txi, tx_hash, create_txi) ++
      [
        ContractCallMutation.new(
          contract_pk,
          caller_pk,
          create_txi,
          txi,
          fun_arg_res,
          aex9_meta_info,
          call_rec
        )
      ]
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
    AeMdw.Ets.inc(:stat_sync_cache, :contracts)

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
    Sync.Name.name_claim_mutations(tx, tx_hash, block_index, txi)
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

  defp log_msg(height, _ignore),
    do: "syncing transactions at generation #{height}"
end
