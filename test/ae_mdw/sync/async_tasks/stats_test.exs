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
      ct_pks =
        [
          "ct_M9yohHgcLjhpp1Z8SaA1UTmRMQzR4FWjJHajGga8KBoZTEPwC",
          "ct_6ZuwbMgcNDaryXTnrLMiPFW2ogE9jxAzz1874BToE81ksWek6",
          "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2"
        ]
        |> Enum.map(&AeMdw.Validate.id!/1)

      on_exit(fn ->
        Enum.each(ct_pks, &setup_delete_async_task/1)
      end)

      pending_count = length(ct_pks)

      # setup new to expected pending
      Enum.each(ct_pks, fn ct_pk ->
        index = {System.system_time(), :update_aex9_presence}
        m_task = Model.async_tasks(index: index, args: [ct_pk])
        Database.dirty_write(Model.AsyncTasks, m_task)
      end)

      assert %{producer_buffer: 0, total_pending: 0} = Stats.counters()
      assert :ok = Stats.update_buffer_len(5, 100)
      assert %{producer_buffer: 5, total_pending: ^pending_count} = Stats.counters()
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

  defp setup_delete_async_task(ct_pk) do
    Model.async_tasks(index: key) =
      Model.AsyncTasks
      |> Database.all_keys()
      |> Enum.map(&Database.fetch!(Model.AsyncTasks, &1))
      |> Enum.find(fn m_task -> Model.async_tasks(m_task, :args) == [ct_pk] end)

    Database.dirty_delete(Model.AsyncTasks, key)
  end
end
