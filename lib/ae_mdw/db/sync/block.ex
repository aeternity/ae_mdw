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
  alias AeMdw.Db.KeyBlockMutation
  alias AeMdw.Db.NamesExpirationMutation
  alias AeMdw.Db.OraclesExpirationMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Db.Sync.Transaction
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Mutation
  alias AeMdw.Log
  alias AeMdw.Node, as: AE
  alias AeMdw.Txs

  require Model
  require Logger

  @log_freq 1_000

  @typep block() :: term()
  @typep block_mutations() :: {Blocks.block_index(), block(), [Mutation.t()]}
  @type height_mutations() :: {Blocks.height(), [block_mutations()]}

  ################################################################################

  @spec blocks_mutations(Blocks.height(), Blocks.mbi(), Txs.txi(), Blocks.height()) ::
          {[height_mutations()], Txs.txi()}
  def blocks_mutations(from_height, from_mbi, from_txi, to_height) do
    {:ok, header} = :aec_chain.get_key_header_by_height(to_height + 1)
    {:ok, initial_hash} = :aec_headers.hash_header(header)

    {heights_hashes, _prev_hash} =
      Enum.map_reduce((to_height + 1)..from_height, initial_hash, fn height, hash ->
        {:ok, kh} = :aec_chain.get_header(hash)
        ^height = :aec_headers.height(kh)
        :key = :aec_headers.type(kh)

        {{height, hash}, :aec_headers.prev_key_hash(kh)}
      end)

    heights_hashes = Enum.reverse(heights_hashes)

    heights_hashes
    |> Enum.zip(Enum.drop(heights_hashes, 1))
    |> Enum.flat_map_reduce(from_txi, fn {{height, kb_hash}, {_next_height, next_kb_hash}}, txi ->
      {key_block, micro_blocks} = AE.Db.get_blocks(kb_hash, next_kb_hash)
      kb_header = :aec_blocks.to_key_header(key_block)

      if rem(height, @log_freq) == 0, do: Log.info("creating mutations for block at #{height}")

      pending_micro_blocks =
        if from_height == height and from_mbi != 0 do
          micro_blocks
          |> Enum.drop(from_mbi)
          |> Enum.with_index(from_mbi)
        else
          Enum.with_index(micro_blocks)
        end

      {micro_blocks_gens, txi} =
        Enum.map_reduce(pending_micro_blocks, txi, fn {micro_block, mbi}, txi ->
          {mutations, txi} = micro_block_mutations(micro_block, mbi, txi)

          {{{height, mbi}, micro_block, mutations}, txi}
        end)

      next_kb_model = Model.block(index: {height + 1, -1}, hash: next_kb_hash, tx_index: txi)

      kb0_mutation =
        if height == 0 do
          key_block = Model.block(index: {0, -1}, hash: kb_hash, tx_index: 0)
          WriteMutation.new(Model.Block, key_block)
        end

      block_rewards_mutation =
        if height >= AE.min_block_reward_height() do
          IntTransfer.block_rewards_mutation(height, kb_header, kb_hash)
        end

      gen_mutations = [
        kb0_mutation,
        block_rewards_mutation,
        NamesExpirationMutation.new(height),
        OraclesExpirationMutation.new(height),
        StatsMutation.new(height, from_height != height or from_mbi != 0),
        KeyBlockMutation.new(next_kb_model)
      ]

      blocks_mutations = micro_blocks_gens ++ [{{height, -1}, key_block, gen_mutations}]

      {[{height, blocks_mutations}], txi}
    end)
  end

  defp micro_block_mutations(mblock, mbi, txi) do
    height = :aec_blocks.height(mblock)
    mb_time = :aec_blocks.time_in_msecs(mblock)
    {:ok, mb_hash} = :aec_headers.hash_header(:aec_blocks.to_micro_header(mblock))
    mb_txs = :aec_blocks.txs(mblock)
    events = AeMdw.Contract.get_grouped_events(mblock)
    tx_ctx = {{height, mbi}, mb_hash, mb_time, events}
    mb_model = Model.block(index: {height, mbi}, tx_index: txi, hash: mb_hash)
    block_mutation = WriteMutation.new(Model.Block, mb_model)

    mutations =
      mb_txs
      |> Enum.with_index(txi)
      |> Enum.reduce([block_mutation], fn {signed_tx, txi}, mutations ->
        transaction_mutations = Transaction.transaction_mutations(signed_tx, txi, tx_ctx)

        mutations ++ transaction_mutations
      end)

    {mutations, txi + length(mb_txs)}
  end

  @spec last_synced_mbi(State.t(), Blocks.height()) :: {:ok, Blocks.mbi()} | :none
  def last_synced_mbi(state, height) do
    case State.prev(state, Model.Block, {height + 1, -1}) do
      {:ok, {^height, mbi}} -> {:ok, mbi}
      {:ok, _prev_key} -> :none
      :none -> :none
    end
  end

  @spec next_txi(State.t()) :: Txs.txi()
  def next_txi(state) do
    case State.prev(state, Model.Tx, nil) do
      :none -> 0
      {:ok, txi} -> txi + 1
    end
  end

  @spec fetch_micro_block(Blocks.block_index()) :: Model.block()
  def fetch_micro_block(block_index) do
    Database.fetch!(Model.Block, block_index)
  end
end
