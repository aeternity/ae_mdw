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
      assert :ok = Stats.update_buffer_len(15)
      assert %{producer_buffer: 15} = Stats.counters()
    end

    test "with pending db records" do
      m_tasks =
        Enum.map(
          [
            "ct_M9yohHgcLjhpp1Z8SaA1UTmRMQzR4FWjJHajGga8KBoZTEPwC",
            "ct_6ZuwbMgcNDaryXTnrLMiPFW2ogE9jxAzz1874BToE81ksWek6",
            "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2"
          ],
          fn ct_id ->
            ct_pk = AeMdw.Validate.id!(ct_id)
            index = {System.system_time(), :update_aex9_state}
            Model.async_task(index: index, args: [ct_pk])
          end
        )

      on_exit(fn ->
        Enum.each(m_tasks, fn Model.async_task(index: key) ->
          Database.dirty_delete(Model.AsyncTask, key)
        end)
      end)

      # setup new to expected pending
      Enum.each(m_tasks, fn m_task ->
        Database.dirty_write(Model.AsyncTask, m_task)
      end)

      pending_count = Database.count(Model.AsyncTask)

      assert %{producer_buffer: 0, total_pending: 0} = Stats.counters()
      assert :ok = Stats.update_buffer_len(10)
      assert %{producer_buffer: 10, total_pending: ^pending_count} = Stats.counters()
    end
  end

  describe "update_consumed/2 and counter/0 success" do
    test "without pending db records" do
      assert :ok = Stats.update_buffer_len(15)
      assert :ok = Stats.inc_long_tasks_count()
      assert :ok = Stats.inc_long_tasks_count()
      assert %{producer_buffer: 15, long_tasks: 2} = Stats.counters()
      assert :ok = Stats.update_consumed(true)
      assert %{producer_buffer: 15, long_tasks: 1} = Stats.counters()
    end
  end
end
