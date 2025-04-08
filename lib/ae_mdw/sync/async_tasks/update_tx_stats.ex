defmodule AeMdw.Sync.AsyncTasks.UpdateTxStats do
  @moduledoc """
  Async work to update tx count, fee and stats without blocking sync.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Log
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State

  alias AeMdw.Sync.AsyncStoreServer

  require Model
  require Logger

  @microsecs 1_000_000
  @seconds_per_day 24 * 3_600

  @spec process(args :: list(), done_fn :: fun()) :: :ok
  def process([started_at], done_fn) do
    state = State.mem_state()

    state
    |> State.get(Model.Stat, :tx_stats)
    |> case do
      :not_found ->
        done_fn.()
        :ok

      {:ok, Model.stat(payload: {old_started_at, _old_stats})} when old_started_at > started_at ->
        done_fn.()
        :ok

      {:ok, _old_stats} ->
        {time_delta, :ok} =
          :timer.tc(fn ->
            tx_stats =
              calculate_fees(state, started_at)

            write_mutation =
              WriteMutation.new(Model.Stat, Model.stat(index: :tx_stats, payload: tx_stats))

            AsyncStoreServer.write_mutations(
              [write_mutation],
              done_fn
            )
          end)

        Log.info("[update_tx_stats] after #{time_delta / @microsecs}s")

        :ok
    end

    :ok
  end

  defp calculate_fees(state, started_at) do
    time_24hs_ago = started_at - @seconds_per_day * 1_000

    with {:ok, {_time, tx_index_24hs_ago}} <- State.next(state, Model.Time, {time_24hs_ago, -1}),
         {:ok, last_tx_index} <- State.prev(state, Model.Tx, nil),
         time_48hs_ago <- time_24hs_ago - @seconds_per_day * 1_000,
         {:ok, {_time, tx_index_48hs_ago}} <- State.next(state, Model.Time, {time_48hs_ago, -1}),
         txs_count_24hs when txs_count_24hs > 0 <- last_tx_index - tx_index_24hs_ago + 1,
         txs_count_48hs <- tx_index_24hs_ago - tx_index_48hs_ago,
         trend <- Float.round((txs_count_24hs - txs_count_48hs) / txs_count_24hs, 2),
         average_tx_fees_24hs when average_tx_fees_24hs > 0 <-
           average_tx_fees(tx_index_24hs_ago, last_tx_index),
         average_tx_fees_48hs <- average_tx_fees(tx_index_48hs_ago, tx_index_24hs_ago),
         fee_trend <-
           Float.round((average_tx_fees_24hs - average_tx_fees_48hs) / average_tx_fees_24hs, 2) do
      {started_at, {{txs_count_24hs, trend}, {average_tx_fees_24hs, fee_trend}}}
    else
      error ->
        Log.error("[update_tx_stats] error calculating tx stats: #{inspect(error)}")
        {started_at, {{0, 0}, {0, 0}}}
    end
  end

  defp average_tx_fees(start_txi, end_txi) do
    txs_count = end_txi - start_txi + 1

    if txs_count != 0 do
      Model.Tx
      |> RocksDbCF.stream(key_boundary: {start_txi, end_txi})
      |> Enum.reduce(0, fn Model.tx(fee: fee), acc ->
        acc + fee
      end)
      |> then(&(&1 / txs_count))
    else
      0
    end
  end
end
