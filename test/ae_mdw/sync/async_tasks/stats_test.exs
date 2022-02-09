defmodule AeMdw.Sync.AsyncTasks.StatsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Stats
  alias AeMdw.Mnesia

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
      db_pending_count = 10
      existing_keys = :mnesia.dirty_all_keys(Model.AsyncTasks)
      existing_tasks = Enum.flat_map(existing_keys, &:mnesia.dirty_read(Model.AsyncTasks, &1))

      keys_to_delete =
        if length(existing_keys) > db_pending_count do
          delete_count = length(existing_keys) - db_pending_count

          # delete to expected pending
          existing_keys
          |> Enum.take(delete_count)
          |> Enum.each(fn key ->
            :mnesia.dirty_delete(Model.AsyncTasks, key)
          end)

          []
        else
          insert_count = db_pending_count - length(existing_keys)

          # setup new to expected pending
          Enum.map(1..insert_count, fn i ->
            index = {System.system_time() + i, :update_aex9_presence}
            m_task = Model.async_tasks(index: index, args: [<<i::256>>])
            :mnesia.dirty_write(Model.AsyncTasks, m_task)
            index
          end)
        end

      on_exit(fn ->
        :mnesia.sync_dirty(fn ->
          Enum.each(keys_to_delete, &Mnesia.delete(Model.AsyncTasks, &1))
          Enum.each(existing_tasks, &Mnesia.write(Model.AsyncTasks, &1))
        end)
      end)

      assert %{producer_buffer: 0, total_pending: 0} = Stats.counters()

      assert :ok = Stats.update_buffer_len(10, 100)

      assert %{producer_buffer: 10, total_pending: ^db_pending_count} = Stats.counters()
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
