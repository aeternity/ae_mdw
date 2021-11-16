defmodule Integration.AeMdw.Sync.AsyncTasks.StoreTest do
  use ExUnit.Case

  @moduletag :integration

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Store

  require Model
  require Ex2ms

  @task_type :update_aex9_presence
  @contract_pk <<123_456::256>>

  describe "save_new/2 and fetch_unprocessed/1 success" do
    test "for an unprocessed task" do
      on_exit(fn ->
        setup_delete_async_task([@contract_pk])
      end)

      Store.save_new(@task_type, [@contract_pk])
      Store.save_new(@task_type, [@contract_pk])
      tasks = Store.fetch_unprocessed(1000)

      assert 1 ==
               Enum.count(tasks, fn Model.async_tasks(args: args) -> args == [@contract_pk] end)
    end

    test "for a task being processed" do
      on_exit(fn ->
        setup_delete_async_task([@contract_pk])
      end)

      Store.save_new(@task_type, [@contract_pk])
      tasks_before = Store.fetch_unprocessed(1000)

      assert Model.async_tasks(index: task_index) =
               Enum.find(tasks_before, fn Model.async_tasks(args: args) ->
                 args == [@contract_pk]
               end)

      Store.set_processing(task_index)
      tasks_after = Store.fetch_unprocessed(1000)

      assert nil ==
               Enum.find(tasks_after, fn Model.async_tasks(args: args) ->
                 args == [@contract_pk]
               end)
    end
  end

  defp setup_delete_async_task(args) do
    task_type = @task_type

    task_mspec =
      Ex2ms.fun do
        {:async_tasks, {ts, ^task_type}, ^args} -> {ts, @task_type}
      end

    :mnesia.sync_dirty(fn ->
      Model.AsyncTasks
      |> :mnesia.select(task_mspec)
      |> Enum.each(&:mnesia.delete(Model.AsyncTasks, &1, :write))
    end)
  end
end
