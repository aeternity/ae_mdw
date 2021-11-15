defmodule AeMdw.Sync.AsyncTasks.StatsTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Stats

  import Support.TestMnesiaSandbox

  require Model

  @contract_pk "ct_2bwK4mxEe3y9SazQRPXE8NdXikSTqF2T9FhNrawRzFA21yacTo"

  describe "update_buffer_len/2 and counter/0 success" do
    test "without pending db records" do
      assert Stats.update_buffer_len(10, 100) == :ok
      assert Stats.counters() == %{producer_buffer: 10, long_tasks: 0, total_pending: 0}
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

        assert Stats.update_buffer_len(10, 100) == :ok

        assert Stats.counters() == %{
                 producer_buffer: 10,
                 long_tasks: 0,
                 total_pending: db_pending_count
               }

        :mnesia.abort(:rollback)
      end
      |> mnesia_sandbox()
    end
  end

  describe "update_consumed/2 and counter/0 success" do
    test "without pending db records" do
      assert :ok == Stats.update_buffer_len(10, 100)
      assert :ok == Stats.update_consumed(false)
      assert Stats.counters() == %{producer_buffer: 9, long_tasks: 0, total_pending: 0}

      assert :ok == Stats.inc_long_tasks_count()
      assert :ok == Stats.inc_long_tasks_count()
      assert Stats.counters() == %{producer_buffer: 9, long_tasks: 2, total_pending: 0}
      assert :ok == update_consumed(true)
      assert Stats.counters() == %{producer_buffer: 9, long_tasks: 1, total_pending: 0}
    end
  end
end
