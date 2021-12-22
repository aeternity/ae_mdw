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
  alias AeMdw.Db.ContractEventsMutation
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.MnesiaWriteMutation
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Name
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Db.WriteFieldsMutation
  alias AeMdw.Db.WriteLinksMutation
  alias AeMdw.Db.WriteTxMutation
  alias AeMdw.Mnesia
  alias AeMdw.Node
  alias AeMdw.Txs
  alias AeMdw.Util.BufferedStream
  alias AeMdwWeb.Websocket.Broadcaster

  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

  @log_freq 1000
  @sync_cache_cleanup_freq 150_000
  @preload_blocks_buffer_size 100
  @micro_blocks_events_buffer_size 100

  ################################################################################

  @spec sync(non_neg_integer() | :safe) :: pos_integer()
  def sync(max_height \\ :safe) do
    max_height = Sync.height((is_integer(max_height) && max_height + 1) || max_height)
    bi_max_kbi = Sync.BlockIndex.sync(max_height) - 1

    case last(Model.Tx) do
      :"$end_of_table" ->
        sync(0, bi_max_kbi, 0)

      max_txi when is_integer(max_txi) ->
        {tx_kbi, _} = Model.tx(read_tx!(max_txi), :block_index)
        next_txi = max_txi + 1
        from_height = tx_kbi + 1
        sync(from_height, bi_max_kbi, next_txi)
    end
  end

  @spec sync(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: pos_integer()
  def sync(from_height, to_height, txi) when from_height <= to_height do
    tracker = Sync.progress_logger(&sync_generation/2, @log_freq, &log_msg/2)

    next_txi =
      from_height..to_height
      |> BufferedStream.map(
        fn height ->
          {key_block, micro_blocks} = AE.Db.get_blocks(height)

          {height, key_block, micro_blocks}
        end,
        buffer_size: @preload_blocks_buffer_size
      )
      |> Enum.reduce(txi, tracker)

    :mnesia.transaction(fn ->
      [succ_kb] = :mnesia.read(Model.Block, {to_height + 1, -1})
      :mnesia.write(Model.Block, Model.block(succ_kb, tx_index: next_txi), :write)
    end)

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

    ct_pk =
      case type do
        :contract_create_tx -> :aect_create_tx.contract_pubkey(tx)
        :contract_call_tx -> :aect_call_tx.contract_pubkey(tx)
        _other_tx -> nil
      end

    contract_events_mutation =
      if ct_pk do
        events = Map.get(mb_events, tx_hash, [])
        ContractEventsMutation.new(ct_pk, events, txi)
      end

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
      contract_events_mutation,
      WriteFieldsMutation.new(type, tx, block_index, txi),
      inner_tx_mutations
    ]
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
  end

  ################################################################################

  defp sync_generation({height, key_block, micro_blocks}, txi) do
    kb_txi = (txi == 0 && -1) || txi
    kb_header = :aec_blocks.to_key_header(key_block)
    kb_hash = ok!(:aec_headers.hash_header(kb_header))
    kb_model = Model.block(index: {height, -1}, tx_index: kb_txi, hash: kb_hash)

    :ets.delete_all_objects(:stat_sync_cache)
    :ets.delete_all_objects(:ct_create_sync_cache)
    :ets.delete_all_objects(:tx_sync_cache)

    block_rewards_mutation =
      if height >= AE.min_block_reward_height() do
        IntTransfer.block_rewards_mutation(height, kb_header, kb_hash)
      end

    initial_mutations =
      [
        Name.expirations_mutation(height),
        Oracle.expirations_mutation(height - 1),
        MnesiaWriteMutation.new(Model.Block, kb_model),
        block_rewards_mutation
      ]
      |> Enum.reject(&is_nil/1)

    {next_txi, _mb_index, mutations} =
      micro_blocks
      |> BufferedStream.async_map(
        fn mblock ->
          events = AeMdw.Contract.get_grouped_events(mblock)

          {mblock, events}
        end,
        buffer_size: @micro_blocks_events_buffer_size
      )
      |> Enum.reduce({txi, 0, initial_mutations}, &micro_block_mutations/2)

    mutations =
      [
        mutations,
        StatsMutation.new(height)
      ]
      |> List.flatten()

    Mnesia.transaction(mutations)

    Broadcaster.broadcast_key_block(key_block, :mdw)

    Enum.each(micro_blocks, fn mblock ->
      Broadcaster.broadcast_micro_block(mblock, :mdw)
      Broadcaster.broadcast_txs(mblock, :mdw)
    end)

    if rem(height, @sync_cache_cleanup_freq) == 0 do
      :ets.delete_all_objects(:name_sync_cache)
      :ets.delete_all_objects(:oracle_sync_cache)
    end

    next_txi
  end

  defp micro_block_mutations({mblock, events}, {txi, mbi, mutations}) do
    height = :aec_blocks.height(mblock)
    mb_time = :aec_blocks.time_in_msecs(mblock)
    mb_hash = ok!(:aec_headers.hash_header(:aec_blocks.to_micro_header(mblock)))
    mb_txi = (txi == 0 && -1) || txi
    mb_model = Model.block(index: {height, mbi}, tx_index: mb_txi, hash: mb_hash)
    mb_txs = :aec_blocks.txs(mblock)
    tx_ctx = {{height, mbi}, mb_hash, mb_time, events}

    txs_mutations =
      mb_txs
      |> Enum.with_index(txi)
      |> Enum.flat_map(&transaction_mutations(&1, tx_ctx))

    mutations =
      List.flatten([
        mutations,
        MnesiaWriteMutation.new(Model.Block, mb_model),
        txs_mutations,
        Aex9AccountPresenceMutation.new(height, mbi)
      ])

    {txi + length(mb_txs), mbi + 1, mutations}
  end

  defp log_msg(height, _ignore),
    do: "syncing transactions at generation #{height}"
end
