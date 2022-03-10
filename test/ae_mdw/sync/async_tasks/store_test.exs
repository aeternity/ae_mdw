defmodule AeMdw.Sync.AsyncTasks.StoreTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Sync.AsyncTasks.Store

  require Model
  require Ex2ms

  @task_type :update_aex9_presence
  @args1 [<<123_456::256>>]
  @args2 [<<123_457::256>>]

  describe "save_new/2 and fetch_unprocessed/1 success" do
    test "for an unprocessed task" do
      on_exit(fn ->
        setup_delete_async_task(@args1)
      end)

      Store.save_new(@task_type, @args1)
      Store.save_new(@task_type, @args1)
      tasks = Store.fetch_unprocessed(1000)

      assert 1 == Enum.count(tasks, fn Model.async_tasks(args: args) -> args == @args1 end)
    end

    test "for a task being processed" do
      on_exit(fn ->
        setup_delete_async_task(@args2)
      end)

      Store.save_new(@task_type, @args2)
      tasks_before = Store.fetch_unprocessed(1000)

      assert Model.async_tasks(index: task_index) =
               Enum.find(tasks_before, fn Model.async_tasks(args: args) ->
                 args == @args2
               end)

      Store.set_processing(task_index)
      tasks_after = Store.fetch_unprocessed(1000)

      assert nil ==
               Enum.find(tasks_after, fn Model.async_tasks(args: args) ->
                 args == @args2
               end)
    end
  end

  defp setup_delete_async_task(args) do
    Model.async_tasks(index: key) =
      Model.AsyncTasks
      |> Database.all_keys()
      |> Enum.map(&Database.fetch!(Model.AsyncTasks, &1))
      |> Enum.find(fn m_task -> Model.async_tasks(m_task, :args) == args end)

    Database.dirty_delete(Model.AsyncTasks, key)
  end
end
