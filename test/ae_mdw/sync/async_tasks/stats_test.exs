defmodule AeMdw.Sync.AsyncTasks.StatsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Stats
  alias AeMdw.Database

  require Model

  setup do
    :ets.insert(:async_tasks_stats, {:async_tasks_stats_key, 0, 0, 0})
    :ok
  end

  describe "update_buffer_len/2 and counter/0 success" do
    test "without pending db records" do
      assert :ok = Stats.update_buffer_len(15, 100)
      assert %{producer_buffer: 15} = Stats.counters()
    end

    test "with pending db records" do
      pending_count = 10

      # setup new to expected pending
      Enum.each(1..pending_count, fn i ->
        index = {System.system_time() + i, :update_aex9_presence}
        m_task = Model.async_tasks(index: index, args: [<<i::256>>])
        Database.dirty_write(Model.AsyncTasks, m_task)
      end)

      assert %{producer_buffer: 0, total_pending: 0} = Stats.counters()
      assert :ok = Stats.update_buffer_len(10, 100)
      assert %{producer_buffer: 10, total_pending: ^pending_count} = Stats.counters()
    end
  end

  describe "update_consumed/2 and counter/0 success" do
    test "without pending db records" do
      assert :ok = Stats.update_buffer_len(15, 100)
      assert :ok = Stats.inc_long_tasks_count()
      assert :ok = Stats.inc_long_tasks_count()
      assert %{producer_buffer: 15, long_tasks: 2} = Stats.counters()
      assert :ok = Stats.update_consumed(true)
      assert %{producer_buffer: 15, long_tasks: 1} = Stats.counters()
    end
  end
end
