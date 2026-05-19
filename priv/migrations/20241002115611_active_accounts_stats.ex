defmodule AeMdw.Migrations.ActiveAccountsStats do
  @moduledoc """
    Add active accounts stats
  """
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.RocksDbCF

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    _table = :ets.new(:time_intervals, [:named_table, {:read_concurrency, true}])

    Model.Tx
    |> AeMdw.Db.RocksDbCF.stream()
    |> Enum.each(fn Model.tx(time: time) ->
      case :ets.lookup(:time_intervals, time) do
        [{^time, intervals}] ->
          intervals

        [] ->
          intervals = AeMdw.Db.Sync.Stats.time_intervals(time)
          :ets.insert(:time_intervals, {time, intervals})
          intervals
      end
    end)

    _table =
      :ets.new(:active_account_counter, [:bag, :named_table, :public, {:write_concurrency, :auto}])

    {_state, created_account_activity_entries} =
      Model.Tx
      |> RocksDbCF.stream()
      |> Task.async_stream(fn Model.tx(id: tx_hash, time: time) ->
        {_, signed_tx} = :aec_db.find_tx_with_location(tx_hash)

        signed_tx
        |> AeMdw.Sync.Transaction.get_ids_from_tx()
        |> Enum.reduce([], fn
          {:id, :account, pubkey}, acc ->
            [{^time, intervals}] = :ets.lookup(:time_intervals, time)

            for interval <- intervals do
              :ets.insert(:active_account_counter, {interval, pubkey})
            end

            [
              WriteMutation.new(
                Model.AccountActivity,
                Model.account_activity(index: {pubkey, time})
              )
              | acc
            ]

          _other, acc ->
            acc
        end)
      end)
      |> Stream.flat_map(fn {:ok, x} -> x end)
      |> Stream.chunk_every(1000)
      |> Enum.reduce({state, 0}, fn mutations, {acc_state, count} ->
        {
          State.commit_db(acc_state, mutations),
          count + length(mutations)
        }
      end)

    stream =
      Stream.resource(
        fn -> :ets.first(:active_account_counter) end,
        fn
          :"$end_of_table" ->
            {:halt, []}

          {interval_type, interval_value} ->
            count =
              :ets.select_count(:active_account_counter, [
                {{{interval_type, interval_value}, :_}, [], [true]}
              ])

            {[
               WriteMutation.new(
                 Model.Statistic,
                 Model.statistic(
                   index: {:active_accounts, interval_type, interval_value},
                   count: count
                 )
               )
             ], :ets.next(:active_account_counter, {interval_type, interval_value})}
        end,
        fn _acc -> :ok end
      )

    {_state, statistic_entries} =
      stream
      |> Stream.chunk_every(1000)
      |> Enum.reduce({state, 0}, fn mutations, {acc_state, count} ->
        {
          State.commit_db(acc_state, mutations),
          count + length(mutations)
        }
      end)

    :ets.delete(:time_intervals)
    :ets.delete(:active_account_counter)

    {:ok, created_account_activity_entries + statistic_entries}
  end
end
