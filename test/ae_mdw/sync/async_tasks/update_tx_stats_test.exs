defmodule AeMdw.Sync.AsyncTasks.UpdateTxStatsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.DbStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks.UpdateTxStats

  require Model

  @hour 3_600_000
  # above the txs and times of other tests
  @txi 10_000_000_000
  @started_at 9_000_000_000_000
  @t36 @started_at - 36 * @hour
  @t12 @started_at - 12 * @hour
  @t1 @started_at - @hour

  setup {AeMdw.TestUtil, :restore_global_state}

  setup do
    on_exit(fn -> AsyncStore.delete(AsyncStore.instance(), Model.Stat, :tx_stats) end)
  end

  test "averages the fees of the txs that are only in the mem state" do
    db_txs = [
      {@txi, 10, @t36},
      {@txi + 1, 10, @t36},
      {@txi + 2, 100, @t12},
      {@txi + 3, 100, @t12}
    ]

    mem_txs = [{@txi + 4, 300, @t1}, {@txi + 5, 300, @t1}]

    # 24h: 4 txs, fees (100 + 100 + 300 + 300) / 4; 48h: txi..txi + 2, (10 + 10 + 100) / 3
    assert {{4, "0.5"}, {"200.0", "0.8"}} = tx_stats(db_txs, mem_txs)
  end

  test "reports the last 24h when all of their txs are only in the mem state" do
    db_txs = [{@txi, 20, @t36}]
    mem_txs = [{@txi + 1, 100, @t12}, {@txi + 2, 300, @t1}]

    # 24h: 2 txs, fees (100 + 300) / 2; 48h: txi..txi + 1, (20 + 100) / 2
    assert {{2, "0.5"}, {"200.0", "0.7"}} = tx_stats(db_txs, mem_txs)
  end

  defp tx_stats(db_txs, mem_txs) do
    on_exit(fn ->
      Enum.each(db_txs, fn {txi, _fee, time} ->
        Database.dirty_delete(Model.Tx, txi)
        Database.dirty_delete(Model.Time, {time, txi})
      end)
    end)

    Enum.each(db_txs, fn {txi, _fee, time} = tx ->
      Database.dirty_write(Model.Tx, m_tx(tx))
      Database.dirty_write(Model.Time, Model.time(index: {time, txi}))
    end)

    empty_state = State.new(MemStore.new(DbStore.new()))

    mem_state =
      Enum.reduce(mem_txs, empty_state, fn {txi, _fee, time} = tx, state ->
        state
        |> State.put(Model.Tx, m_tx(tx))
        |> State.put(Model.Time, Model.time(index: {time, txi}))
      end)

    :persistent_term.put(:global_state, mem_state)

    test_pid = self()
    assert :ok = UpdateTxStats.process([@started_at], fn -> send(test_pid, :done) end)
    assert_receive :done, 1_000

    assert {:ok, Model.stat(payload: {@started_at, tx_stats})} =
             AsyncStore.instance()
             |> State.new()
             |> State.get(Model.Stat, :tx_stats)

    tx_stats
  end

  defp m_tx({txi, fee, time}),
    do: Model.tx(index: txi, id: <<txi::256>>, block_index: {1, 0}, time: time, fee: fee)
end
