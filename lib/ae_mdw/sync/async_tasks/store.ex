defmodule AeMdw.Sync.AsyncTasks.Store do
  @moduledoc """
  Read-write access for async tasks persistent data and cache for processing state.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.Util

  require Ex2ms
  require Model

  @typep task_index() :: {pos_integer(), atom()}

  @spec init() :: :ok
  def init do
    :ets.new(:async_tasks_processing, [:named_table, :ordered_set, :public])
    :ok
  end

  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(:async_tasks_processing)
    :ok
  end

  @spec fetch_unprocessed(pos_integer()) :: [Model.async_tasks_record()]
  def fetch_unprocessed(max_amount) do
    any_spec =
      Ex2ms.fun do
        record -> record
      end

    {m_tasks, _cont} = Util.select(Model.AsyncTasks, any_spec, max_amount)

    Enum.filter(m_tasks, fn Model.async_tasks(index: index) ->
      not :ets.member(:async_tasks_processing, index)
    end)
  end

  @spec save_new(atom(), list()) :: :ok
  def save_new(task_type, args) do
    :mnesia.sync_transaction(fn ->
      if not is_enqueued?(task_type, args) do
        index = {System.system_time(), task_type}
        m_task = Model.async_tasks(index: index, args: args)
        :mnesia.write(Model.AsyncTasks, m_task, :write)
      end
    end)

    :ok
  end

  @spec set_processing(task_index()) :: :ok
  def set_processing(task_index) do
    :ets.insert(:async_tasks_processing, task_index)
    :ok
  end

  @spec set_done(task_index()) :: :ok
  def set_done(task_index) do
    :mnesia.sync_transaction(fn ->
      :mnesia.delete(Model.AsyncTasks, task_index, :write)
    end)

    :ets.delete_object(:async_tasks_processing, task_index)
    :ok
  end

  #
  # Private functions
  #
  defp is_enqueued?(task_type, args) do
    exists_spec =
      Ex2ms.fun do
        {:_, {:_, ^task_type}, ^args} -> true
      end

    case :mnesia.select(Model.AsyncTasks, exists_spec, 1, :read) do
      {[true], _cont} -> true
      {[], _cont} -> false
    end
  end
end
