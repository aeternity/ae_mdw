defmodule AeMdw.Db.Sync.Block do
  @moduledoc """
  Syncs all blocks and transactions contained in them from a given range of
  heights.

  The steps for syncing a range of generations is:

    1. Retrieve all of the key block hashes belonging to that range.
    2. Create a key block in the Model.Block table for each of those
       blocks.
    3. For each key block:
       3.1. Retrieve the key block micro blocks from chain.
       3.2. Skip processing the microblocks that were already created,
            get the latest txi from them.
       3.3. Get the mutations from each micro-block and execute them.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.NamesExpirationMutation
  alias AeMdw.Db.OraclesExpirationMutation
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Db.Sync.Transaction
  alias AeMdw.Db.WriteTxnMutation
  alias AeMdw.Log
  alias AeMdw.Node, as: AE
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdwWeb.Websocket.Broadcaster

  require Model
  require Logger

  @log_freq 10_000

  ################################################################################

  @spec sync(Blocks.height(), Blocks.height()) :: :ok
  def sync(from_height, to_height) do
    {:ok, header} = :aec_chain.get_key_header_by_height(to_height + 1)
    {:ok, initial_hash} = :aec_headers.hash_header(header)

    {heights_hashes, _prev_hash} =
      Enum.map_reduce((to_height + 1)..from_height, initial_hash, fn height, hash ->
        if rem(height, @log_freq) == 0, do: Log.info("syncing block index at #{height}")

        {:ok, kh} = :aec_chain.get_header(hash)
        ^height = :aec_headers.height(kh)
        :key = :aec_headers.type(kh)

        {{height, hash}, :aec_headers.prev_key_hash(kh)}
      end)

    heights_hashes = Enum.reverse(heights_hashes)

    heights_hashes
    |> Enum.drop(if from_height == 0, do: 0, else: 1)
    |> Enum.map(fn {height, hash} ->
      kb_model = Model.block(index: {height, -1}, hash: hash, tx_index: 0)

      WriteTxnMutation.new(Model.Block, kb_model)
    end)
    |> Database.commit()

    heights_hashes
    |> Enum.zip(Enum.drop(heights_hashes, 1))
    |> Enum.each(fn {{height, kb_hash}, {_next_height, next_kb_hash}} ->
      if rem(height, @log_freq) == 0, do: Log.info("syncing transactions at generation #{height}")

      sync_generation(height, kb_hash, next_kb_hash)
    end)
  end

  defp sync_generation(height, kb_hash, next_kb_hash) do
    {key_block, micro_blocks} = AE.Db.get_blocks(kb_hash, next_kb_hash)
    kb_header = :aec_blocks.to_key_header(key_block)

    {:ok, {^height, last_mbi}} = Database.prev_key(Model.Block, {height + 1, -1})
    last_txi = Database.last_key(Model.Tx, -1) + 1

    :ets.delete_all_objects(:stat_sync_cache)
    :ets.delete_all_objects(:ct_create_sync_cache)
    :ets.delete_all_objects(:tx_sync_cache)

    next_txi =
      micro_blocks
      |> Enum.with_index()
      |> Enum.drop(last_mbi + 1)
      |> Enum.reduce(last_txi, fn {micro_block, mbi}, txi ->
        {txn_mutations, txi} = micro_block_mutations(micro_block, mbi, txi)

        Database.commit(txn_mutations)
        Producer.commit_enqueued()

        Broadcaster.broadcast_micro_block(micro_block, :mdw)
        Broadcaster.broadcast_txs(micro_block, :mdw)

        txi
      end)

    next_kb_model = Model.block(index: {height + 1, -1}, tx_index: next_txi, hash: next_kb_hash)

    block_rewards_mutation =
      if height >= AE.min_block_reward_height() do
        IntTransfer.block_rewards_mutation(height, kb_header, kb_hash)
      end

    Database.commit([
      block_rewards_mutation,
      NamesExpirationMutation.new(height),
      OraclesExpirationMutation.new(height),
      StatsMutation.new(height, last_mbi == -1),
      WriteTxnMutation.new(Model.Block, next_kb_model)
    ])

    Broadcaster.broadcast_key_block(key_block, :mdw)
  end

  defp micro_block_mutations(mblock, mbi, txi) do
    height = :aec_blocks.height(mblock)
    mb_time = :aec_blocks.time_in_msecs(mblock)
    {:ok, mb_hash} = :aec_headers.hash_header(:aec_blocks.to_micro_header(mblock))
    mb_txs = :aec_blocks.txs(mblock)
    events = AeMdw.Contract.get_grouped_events(mblock)
    tx_ctx = {{height, mbi}, mb_hash, mb_time, events}

    txn_txs_mutations =
      mb_txs
      |> Enum.with_index(txi)
      |> Enum.reduce([], fn {signed_tx, txi}, txn_mutations_acc ->
        txn_mutations = Transaction.transaction_mutations(signed_tx, txi, tx_ctx)

        txn_mutations_acc ++ txn_mutations
      end)

    mb_model = Model.block(index: {height, mbi}, tx_index: txi, hash: mb_hash)

    txn_mutations = [WriteTxnMutation.new(Model.Block, mb_model) | txn_txs_mutations]

    {txn_mutations, txi + length(mb_txs)}
  end

  @spec synced_height :: Blocks.height() | -1
  def synced_height do
    case Database.last_key(Model.DeltaStat) do
      :none -> -1
      {:ok, height} -> height
    end
  end
end
