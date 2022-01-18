defmodule AeMdw.Migrations.ReindexIntTransfersAccIndex do
  @moduledoc """
  Creates a new index for internal transfers and destroys the previous one
  after loading all the data.

  Right now, the `TargetIntTransferTx` mnesia table is indexed by
  `{account_pk, gen_txi, kind, ref_txi}`. This doesn't allow to filter by both
   account and kind with results sorted by gen_txi.

  Instead, the new index created on this migration, named
  `TargetKindIntTransferTx`, will have `{account_pk, kind, gen_txi, ref_txi}` as
   a key, which allows to filter by both account and kind on a given range.

  This change, however, won't allow to filter by a kind prefix (sorted by
  gen_txi), since it can only be applied for a specific account. But this
  features isn't needed anyway, because the values the `kind` field may have
  are fixed and known.
  """

  alias AeMdw.Db.Model

  require Logger

  @int_transfer_table Model.IntTransferTx
  @target_kind_int_transfer_table Model.TargetKindIntTransferTx
  @target_int_transfer_table Model.TargetIntTransferTx
  @gen_batches_size 1_000
  @min_int -100
  @end_token :"$end_of_table"

  @doc """
  This migration will not store any state - it's either run fully or not - if
  it throws an error in the middle of the run it will re-run next time this
  migration is run from scratch.

  The way to know if this migration was completed or not is to check if the
  `TargetIntTransferTx` table does not exist.

  Steps:
    1. Check if `TargetIntTransferTx` exists. Ignore migration if it doesn't.
    2. Split 0..last_gen into batches of 1_000 generations.
    3. For each of these generations range, grab the transfers from the
       `IntTransferTx` table and create a record for each one in the newly
       created `TargetKindIntTransferTx` table.
    4. Destroy the `TargetIntTransferTx` table.
  """
  @spec run(boolean()) :: {:ok, {non_neg_integer(), pos_integer()}}
  def run(from_startup?) do
    run(from_startup?, @target_int_transfer_table in :mnesia.system_info(:tables))
  end

  defp run(_from_startup?, true) do
    {{last_gen, _txi}, _kind, _account_pk, _ref_txi} = :mnesia.dirty_last(@int_transfer_table)
    batches_count = div(last_gen + @gen_batches_size - 1, @gen_batches_size)

    log("processing #{batches_count} batches of #{@gen_batches_size} generations")

    {duration_microseconds, reindexed_count} = :timer.tc(&reindex_transfers/1, [batches_count])
    duration = div(duration_microseconds, 1_000_000)

    log("indexed #{reindexed_count} records in #{duration}s")

    :mnesia.delete_table(@target_int_transfer_table)

    {:ok, {reindexed_count, duration}}
  end

  defp run(_from_startup?, false) do
    log("aborting: transfers reindex not needed")

    {:ok, {0, 0}}
  end

  defp reindex_transfers(batches_count) do
    0..(batches_count - 1)
    |> Enum.map(fn index ->
      start_gen = index * @gen_batches_size
      next_gen = start_gen + @gen_batches_size

      indexed_count = reindex_gen_range_transfers(start_gen, next_gen)

      log("batch #{index} done")

      {index, indexed_count}
    end)
    |> Enum.map(fn {_index, indexed_count} -> indexed_count end)
    |> Enum.reduce(0, &:erlang.+/2)
  end

  defp reindex_gen_range_transfers(start_gen, next_gen) do
    keys =
      {{start_gen, @min_int}, nil, nil, nil}
      |> Stream.unfold(fn
        @end_token ->
          nil

        key ->
          next_key = :mnesia.dirty_next(@int_transfer_table, key)
          {next_key, next_key}
      end)
      |> Stream.reject(&match?(@end_token, &1))
      |> Stream.take_while(fn {{gen, _txi}, _kind, _account_pk, _ref_txi} -> gen < next_gen end)
      |> Stream.map(fn {{gen, txi}, kind, account_pk, ref_txi} ->
        {:target_kind_int_transfer_tx, {account_pk, kind, {gen, txi}, ref_txi}, nil}
      end)

    {:atomic, indexed_count} =
      :mnesia.transaction(fn ->
        keys
        |> Stream.each(fn target_kind_tx ->
          :mnesia.write(@target_kind_int_transfer_table, target_kind_tx, :write)
        end)
        |> Enum.count()
      end)

    indexed_count
  end

  defp log(msg), do: Logger.info("[ReindexIntTransfersAccIndex migration] #{msg}", sync: true)
end
