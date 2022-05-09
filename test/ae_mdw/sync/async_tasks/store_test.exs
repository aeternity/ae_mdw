defmodule AeMdw.Sync.AsyncTasks.StoreTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Sync.AsyncTasks.Store

  require Model
  require Ex2ms

  @task_type :update_aex9_state
  @args1 [<<123_456::256>>]
  @extra_args1 [{543_211, 11}, 12_345_678]

  @args2 [<<123_457::256>>]
  @extra_args2 [{543_212, 12}, 12_345_679]

  describe "save_new/2 and fetch_unprocessed/1 success" do
    test "for an unprocessed task" do
      on_exit(fn ->
        setup_delete_async_task(@args1)
      end)

      Store.save_new(@task_type, @args1)
      Store.save_new(@task_type, @args1, @extra_args1)
      tasks = Store.fetch_unprocessed(1000)

      assert 1 == Enum.count(tasks, fn Model.async_task(args: args) -> args == @args1 end)
    end

    test "for a task being processed" do
      on_exit(fn ->
        setup_delete_async_task(@args2)
      end)

      Store.save_new(@task_type, @args2, @extra_args2)
      tasks_before = Store.fetch_unprocessed(1000)

      assert Model.async_task(index: task_index) =
               Enum.find(tasks_before, fn Model.async_task(args: args, extra_args: extra_args) ->
                 args == @args2 and extra_args == @extra_args2
               end)

      Store.set_processing(task_index)
      tasks_after = Store.fetch_unprocessed(1000)

      assert nil ==
               Enum.find(tasks_after, fn Model.async_task(args: args) ->
                 args == @args2
               end)
    end
  end

  defp setup_delete_async_task(args) do
    Model.async_task(index: key) =
      Model.AsyncTask
      |> Database.all_keys()
      |> Enum.map(&Database.fetch!(Model.AsyncTask, &1))
      |> Enum.find(fn m_task -> Model.async_task(m_task, :args) == args end)

    Database.dirty_delete(Model.AsyncTask, key)
  end
end
