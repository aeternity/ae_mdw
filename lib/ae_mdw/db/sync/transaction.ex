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
  alias AeMdw.Db.ContractEventsMutation
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.KeyBlocksMutation
  alias AeMdw.Db.MnesiaWriteMutation
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Name
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Db.WriteFieldsMutation
  alias AeMdw.Db.WriteFieldMutation
  alias AeMdw.Db.WriteLinksMutation
  alias AeMdw.Db.WriteTxMutation
  alias AeMdw.Mnesia
  alias AeMdw.Node
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Txs
  alias AeMdwWeb.Websocket.Broadcaster

  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

  @log_freq 1000
  @sync_cache_cleanup_freq 150_000

  ################################################################################

  @spec sync(non_neg_integer() | :safe) :: pos_integer()
  def sync(max_height \\ :safe) do
    max_height = Sync.height((is_integer(max_height) && max_height + 1) || max_height)
    bi_max_kbi = Sync.BlockIndex.sync(max_height) - 1

    case last(Model.Tx) do
      :"$end_of_table" ->
        sync(0, bi_max_kbi, 0)

      max_txi when is_integer(max_txi) ->
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

    inner_tx_mutations =
      if type == :ga_meta_tx or type == :paying_for_tx do
        inner_signed_tx = Sync.InnerTx.signed_tx(type, tx)
        # indexes the inner with the txi from the wrapper/outer
        transaction_mutations({inner_signed_tx, txi}, tx_ctx, true)
      end

    :ets.insert(:tx_sync_cache, {txi, model_tx})

    [
      WriteTxMutation.new(model_tx, type, txi, mb_time, inner_tx?),
      WriteLinksMutation.new(type, tx, signed_tx, txi, tx_hash, block_index, block_hash),
      tx_mutations(type, tx, signed_tx, txi, tx_hash, block_index, block_hash, mb_events),
      WriteFieldsMutation.new(type, tx, block_index, txi),
      inner_tx_mutations
    ]
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
  end

  ################################################################################

  defp sync_generation(height, txi) do
    {:atomic, gen_fully_synced?} =
      :mnesia.transaction(fn ->
        case :mnesia.read(Model.Block, {height + 1, -1}) do
          [] -> false
          [Model.block(tx_index: next_txi)] -> not is_nil(next_txi)
        end
      end)

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

    [
      Name.expirations_mutation(height),
      Oracle.expirations_mutation(height - 1)
    ]
    |> Mnesia.transaction()

    last_mbi =
      case Mnesia.prev_key(Model.Block, {height + 1, -1}) do
        {:ok, {^height, last_mbi}} -> last_mbi
        {:ok, _other_height} -> -1
        :none -> -1
      end

    {next_txi, _mb_index} =
      Enum.reduce(micro_blocks, {txi, 0}, fn mblock, {txi, mbi} = txi_acc ->
        if mbi > last_mbi do
          {mutations, acc} = micro_block_mutations(mblock, txi_acc)
          Mnesia.transaction(mutations)
          Producer.commit_enqueued()
          Broadcaster.broadcast_micro_block(mblock, :mdw)
          Broadcaster.broadcast_txs(mblock, :mdw)
          acc
        else
          {txi, mbi + 1}
        end
      end)

    kb_model = Model.block(index: {height, -1}, tx_index: kb_txi, hash: kb_hash)

    if height >= AE.min_block_reward_height() do
      Mnesia.transaction([
        IntTransfer.block_rewards_mutation(height, kb_header, kb_hash)
      ])
    end

    Mnesia.transaction([
      Stats.new_mutation(height, last_mbi == -1),
      KeyBlocksMutation.new(kb_model, next_txi)
    ])

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

    mutations =
      List.flatten([
        MnesiaWriteMutation.new(Model.Block, mb_model),
        txs_mutations,
        Aex9AccountPresenceMutation.new(height, mbi)
      ])

    {mutations, {txi + length(mb_txs), mbi + 1}}
  end

  defp tx_mutations(
         :contract_create_tx,
         tx,
         _signed_tx,
         txi,
         tx_hash,
         _block_index,
         block_hash,
         mb_events
       ) do
    contract_pk = :aect_create_tx.contract_pubkey(tx)
    owner_pk = :aect_create_tx.owner_pubkey(tx)
    events = Map.get(mb_events, tx_hash, [])

    :ets.insert(:ct_create_sync_cache, {contract_pk, txi})

    mutations = [
      ContractEventsMutation.new(contract_pk, events, txi)
      | origin_mutations(:contract_create_tx, nil, contract_pk, txi, tx_hash)
    ]

    case Contract.get_info(contract_pk) do
      {:ok, contract_info} ->
        call_rec = Contract.get_init_call_rec(contract_pk, tx, block_hash)

        aex9_meta_info =
          if Contract.is_aex9?(contract_info) do
            Contract.aex9_meta_info(contract_pk)
          end

        mutations ++
          [
            ContractCreateMutation.new(contract_pk, txi, owner_pk, aex9_meta_info, call_rec)
          ]

      {:error, _reason} ->
        mutations
    end
  end

  defp tx_mutations(
         :contract_call_tx,
         tx,
         _signed_tx,
         txi,
         tx_hash,
         _block_index,
         block_hash,
         mb_events
       ) do
    contract_pk = :aect_call_tx.contract_pubkey(tx)
    create_txi = Sync.Contract.get_txi(contract_pk)
    events = Map.get(mb_events, tx_hash, [])

    {fun_arg_res, call_rec} =
      Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)

    [
      ContractEventsMutation.new(contract_pk, events, txi),
      ContractCallMutation.new(create_txi, txi, fun_arg_res, call_rec)
    ]
  end

  defp tx_mutations(
         :channel_create_tx,
         _tx,
         signed_tx,
         txi,
         tx_hash,
         _block_index,
         _block_hash,
         _mb_events
       ) do
    {:ok, channel_pk} = :aesc_utils.channel_pubkey(signed_tx)

    origin_mutations(:channel_create_tx, nil, channel_pk, txi, tx_hash)
  end

  defp tx_mutations(
         :ga_attach_tx,
         tx,
         _signed_tx,
         txi,
         tx_hash,
         _block_index,
         _block_hash,
         _mb_events
       ) do
    contract_pk = :aega_attach_tx.contract_pubkey(tx)
    :ets.insert(:ct_create_sync_cache, {contract_pk, txi})
    AeMdw.Ets.inc(:stat_sync_cache, :contracts)

    origin_mutations(:ga_attach_tx, nil, contract_pk, txi, tx_hash)
  end

  defp tx_mutations(_type, _tx, _signed_tx, _txi, _tx_hash, _block_index, _block_hash, _mb_events) do
    []
  end

  defp origin_mutations(tx_type, pos, pubkey, txi, tx_hash) do
    m_origin = Model.origin(index: {tx_type, pubkey, txi}, tx_id: tx_hash)
    m_rev_origin = Model.rev_origin(index: {txi, tx_type, pubkey})

    [
      MnesiaWriteMutation.new(Model.Origin, m_origin),
      MnesiaWriteMutation.new(Model.RevOrigin, m_rev_origin),
      WriteFieldMutation.new(tx_type, pos, pubkey, txi)
    ]
  end

  defp log_msg(height, _ignore),
    do: "syncing transactions at generation #{height}"
end
