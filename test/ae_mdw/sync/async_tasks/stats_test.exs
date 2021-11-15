defmodule AeMdw.Sync.AsyncTasks.StatsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Stats

  import Support.TestMnesiaSandbox

  require Model

  @contract_pk "ct_2bwK4mxEe3y9SazQRPXE8NdXikSTqF2T9FhNrawRzFA21yacTo"

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
      fn ->
        db_pending_count = 50
        # setup delete existing
        existing = Model.AsyncTasks |> :mnesia.all_keys()

        if length(existing) > db_pending_count do
          delete_count = length(existing) - db_pending_count

          existing
          |> Enum.take(delete_count)
          |> Enum.each(fn key ->
            :mnesia.delete(Model.AsyncTasks, key, :write)
          end)
        else
          insert_count = db_pending_count - length(existing)

          # setup new
          Enum.each(1..insert_count, fn i ->
            index = {System.system_time() + i, :update_aex9_presence}
            m_task = Model.async_tasks(index: index, args: [@contract_pk])
            :mnesia.write(Model.AsyncTasks, m_task, :write)
            index
          end)
        end

        assert %{producer_buffer: 0, total_pending: 0} = Stats.counters()

        assert :ok = Stats.update_buffer_len(10, 100)

        assert %{producer_buffer: 10, total_pending: ^db_pending_count} = Stats.counters()

        :mnesia.abort(:rollback)
      end
      |> mnesia_sandbox()
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
