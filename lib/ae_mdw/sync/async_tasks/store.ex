defmodule AeMdw.Sync.AsyncTasks.Store do
  @moduledoc """
  Read-write access for async tasks persistent data and cache for processing state.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Log

  require Ex2ms
  require Log
  require Model

  @typep task_index() :: {pos_integer(), atom()}

  @max_buffer_size 100

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

  @spec fetch_unprocessed() :: [Model.async_tasks_record()]
  def fetch_unprocessed() do
    Ex2ms.fun do record -> record end
    |> safe_fetch(@max_buffer_size)
    |> Enum.filter(fn Model.async_tasks(index: index) ->
      not :ets.member(:async_tasks_processing, index)
    end)
  end

  @spec save(atom(), list()) :: :ok
  def save(task_type, args) do
    :mnesia.sync_transaction(fn ->
      index = {System.system_time(), task_type}
      m_task = Model.async_tasks(index: index, args: args)
      :mnesia.write(Model.AsyncTasks, m_task, :write)
    end)

    :ok
  end

  @spec is_enqueued?(atom(), list()) :: boolean()
  def is_enqueued?(task_type, args) do
    exists_spec =
      Ex2ms.fun do
        {:_, {:_, ^task_type}, ^args} -> true
      end

    [] != safe_fetch(exists_spec)
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

  def safe_fetch(record_spec, max_num_records \\ 1) do
    fn ->
      :mnesia.select(Model.AsyncTasks, record_spec, max_num_records, :read)
    end
    |> :mnesia.transaction()
    |> case do
      {:atomic, {m_tasks, _cont}} ->
        m_tasks
      {:aborted, reason} ->
        Log.warn("AsyncTasks fetch aborted due to #{inspect reason}")
        []
    end
  end
end
