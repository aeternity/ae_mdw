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
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.KeyBlockMutation
  alias AeMdw.Db.NamesExpirationMutation
  alias AeMdw.Db.OraclesExpirationMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Transaction
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Mutation
  alias AeMdw.Log
  alias AeMdw.Node, as: AE
  alias AeMdw.Node.Db
  alias AeMdw.Stats
  alias AeMdw.Txs

  require Model
  require Logger

  @log_freq 1_000

  @typep block() :: term()
  @typep block_mutations() :: {Blocks.block_index(), block(), [Mutation.t()]}
  @type height_mutations() :: {Blocks.height(), [block_mutations()]}

  ################################################################################

  @spec blocks_mutations(
          Blocks.height(),
          Blocks.mbi(),
          Txs.txi(),
          Blocks.height() | Blocks.block_hash()
        ) ::
          {[height_mutations()], Txs.txi()}
  def blocks_mutations(from_height, from_mbi, from_txi, to_height_or_hash) do
    from_height
    |> Db.get_blocks_per_height(to_height_or_hash)
    |> Enum.flat_map_reduce(from_txi, fn {key_block, micro_blocks, next_kb_hash}, txi ->
      height = :aec_blocks.height(key_block)
      kb_header = :aec_blocks.to_key_header(key_block)
      {:ok, kb_hash} = :aec_headers.hash_header(kb_header)
      starting_from_mb0? = from_height != height or from_mbi == 0

      if rem(height, @log_freq) == 0, do: Log.info("creating mutations for block at #{height}")

      pending_micro_blocks =
        if starting_from_mb0? do
          Enum.with_index(micro_blocks)
        else
          micro_blocks
          |> Enum.drop(from_mbi)
          |> Enum.with_index(from_mbi)
        end

      {micro_blocks_gens, txi} =
        Enum.map_reduce(pending_micro_blocks, txi, fn {micro_block, mbi}, txi ->
          {mutations, txi} = micro_block_mutations(micro_block, mbi, txi)

          {{{height, mbi}, micro_block, mutations}, txi}
        end)

      next_kb_mutation =
        if next_kb_hash do
          key_block = Model.block(index: {height + 1, -1}, hash: next_kb_hash, tx_index: txi)

          KeyBlockMutation.new(key_block)
        end

      kb0_mutation =
        if height == 0 do
          key_block = Model.block(index: {0, -1}, hash: kb_hash, tx_index: 0)
          WriteMutation.new(Model.Block, key_block)
        end

      block_rewards_mutation =
        if height >= AE.min_block_reward_height() do
          IntTransfer.block_rewards_mutations(height, kb_header, kb_hash)
        end

      gen_mutations = [
        kb0_mutation,
        block_rewards_mutation,
        NamesExpirationMutation.new(height),
        OraclesExpirationMutation.new(height),
        Stats.mutation(height, key_block, micro_blocks, from_txi, txi, starting_from_mb0?),
        next_kb_mutation
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
end
