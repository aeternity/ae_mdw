defmodule AeMdw.Sync.AsyncTasks.StoreTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Store

  require Model
  require Ex2ms

  @task_type :update_aex9_state

  describe "add/0" do
    test "inserts not enqueued task once" do
      dedup_args = [:crypto.strong_rand_bytes(32)]

      on_exit(fn ->
        :ets.delete(:async_tasks_pending, {@task_type, dedup_args})
      end)

      m_task1 =
        Model.async_task(
          index: {System.unique_integer(), @task_type},
          args: dedup_args,
          extra_args: [{1, 1}, 0]
        )

      m_task2 =
        Model.async_task(
          index: {System.unique_integer(), @task_type},
          args: dedup_args,
          extra_args: [{1, 1}, 1]
        )

      Store.add(m_task1, only_new: false)
      Store.add(m_task2, only_new: false)

      assert [{{@task_type, dedup_args}, m_task1}] ==
               :ets.lookup(:async_tasks_pending, {@task_type, dedup_args})
    end

    test "inserts again a task when not enqueued" do
      dedup_args = [:crypto.strong_rand_bytes(32)]

      on_exit(fn ->
        :ets.delete(:async_tasks_pending, {@task_type, dedup_args})
      end)

      m_task1 =
        Model.async_task(
          index: {System.unique_integer(), @task_type},
          args: dedup_args,
          extra_args: [{1, 1}, 0]
        )

      m_task2 =
        Model.async_task(
          index: {System.unique_integer(), @task_type},
          args: dedup_args,
          extra_args: [{1, 1}, 0]
        )

      Store.add(m_task1, only_new: false)

      assert [{{@task_type, dedup_args}, m_task1}] ==
               :ets.lookup(:async_tasks_pending, {@task_type, dedup_args})

      :ets.delete(:async_tasks_pending, {@task_type, dedup_args})

      Store.add(m_task2, only_new: false)

      assert [{{@task_type, dedup_args}, m_task2}] ==
               :ets.lookup(:async_tasks_pending, {@task_type, dedup_args})
    end

    test "does not insert a task when not enqueued if not new" do
      dedup_args = [:crypto.strong_rand_bytes(32)]

      m_task1 =
        Model.async_task(
          index: {System.unique_integer(), @task_type},
          args: dedup_args,
          extra_args: [{1, 1}, 0]
        )

      m_task2 =
        Model.async_task(
          index: {System.unique_integer(), @task_type},
          args: dedup_args,
          extra_args: [{1, 1}, 0]
        )

      Store.add(m_task1, only_new: false)

      assert [{{@task_type, dedup_args}, m_task1}] ==
               :ets.lookup(:async_tasks_pending, {@task_type, dedup_args})

      :ets.delete(:async_tasks_pending, {@task_type, dedup_args})

      Store.add(m_task2, only_new: true)

      refute [{{@task_type, dedup_args}, m_task2}] ==
               :ets.lookup(:async_tasks_pending, {@task_type, dedup_args})
    end
  end

  describe "fetch_unprocessed/0" do
    test "returns tasks when unprocessed" do
      args1 = [:crypto.strong_rand_bytes(32)]
      args2 = [:crypto.strong_rand_bytes(32)]
      task_index = {System.unique_integer(), @task_type}

      on_exit(fn ->
        :ets.delete(:async_tasks_pending, {@task_type, args1})
        :ets.delete(:async_tasks_pending, {@task_type, args2})
        Database.dirty_delete(Model.AsyncTask, task_index)
      end)

      extra_args = [{543_211, 11}, 12_345_678]

      m_task1 = Model.async_task(index: task_index, args: args1, extra_args: extra_args)
      m_task2 = Model.async_task(index: task_index, args: args2, extra_args: extra_args)

      Store.add(m_task1, only_new: false)
      Store.add(m_task2, only_new: false)
      tasks = Store.fetch_unprocessed()

      assert 1 == Enum.count(tasks, fn m_task -> m_task == m_task1 end)
      assert 1 == Enum.count(tasks, fn m_task -> m_task == m_task2 end)
    end

    test "does not return a task being processed" do
      args = [:crypto.strong_rand_bytes(32)]
      extra_args = [{543_212, 12}, 12_345_679]

      task_index = {System.unique_integer(), @task_type}
      m_task = Model.async_task(index: task_index, args: args, extra_args: extra_args)

      on_exit(fn ->
        :ets.delete(:async_tasks_pending, {@task_type, args})
        :ets.delete(:async_tasks_processing, task_index)
        Database.dirty_delete(Model.AsyncTask, task_index)
      end)

      Store.add(m_task, only_new: false)
      tasks_before = Store.fetch_unprocessed()

      assert 1 == Enum.count(tasks_before, &(&1 == m_task))

      Store.set_processing(task_index)
      tasks_after = Store.fetch_unprocessed()

      refute Enum.find(tasks_after, &(&1 == m_task))
    end
  end

  describe "save/0" do
    test "succeeds saving not only pending tasks but in processing state as well" do
      args1 = [:crypto.strong_rand_bytes(32)]
      args2 = [:crypto.strong_rand_bytes(32)]
      extra_args = [{543_212, 13}, 12_345_680]

      task_index1 = {System.unique_integer(), @task_type}
      task_index2 = {System.unique_integer(), @task_type}
      m_task1 = Model.async_task(index: task_index1, args: args1, extra_args: extra_args)
      m_task2 = Model.async_task(index: task_index2, args: args2, extra_args: extra_args)

      on_exit(fn ->
        :ets.delete(:async_tasks_pending, {@task_type, args1})
        :ets.delete(:async_tasks_pending, {@task_type, args2})
        :ets.delete(:async_tasks_processing, task_index2)
        Database.dirty_delete(Model.AsyncTask, task_index1)
        Database.dirty_delete(Model.AsyncTask, task_index2)
      end)

      Store.add(m_task1, only_new: false)
      Store.add(m_task2, only_new: false)
      Store.set_processing(task_index2)
      Store.save()

      tasks = Store.fetch_unprocessed()

      assert 1 == Enum.count(tasks, fn m_task -> m_task == m_task1 end)
      refute Enum.find(tasks, fn m_task -> m_task == m_task2 end)
    end
  end
end
