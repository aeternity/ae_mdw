defmodule AeMdw.Sync.AsyncTasks.Store do
  @moduledoc """
  Read-write access for async tasks persistent data and cache for processing state.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Database

  require Ex2ms
  require Model

  @processing_tab :async_tasks_processing
  @args_tab :async_tasks_args

  @spec init() :: :ok
  def init do
    :ets.new(@processing_tab, [:named_table, :set, :public])
    :ets.new(@args_tab, [:named_table, :set, :public])
    :ok
  end

  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(@processing_tab)
    :ets.delete_all_objects(@args_tab)
    cache_tasks_by_args()
    :ok
  end

  @spec fetch_unprocessed(pos_integer()) :: [Model.async_task_record()]
  def fetch_unprocessed(max_amount) do
    fetch_all()
    |> Enum.take(max_amount)
    |> Enum.filter(fn Model.async_task(index: index) ->
      not :ets.member(@processing_tab, index)
    end)
  end

  @spec save_new(Model.async_task_type(), Model.async_task_args(), Model.async_task_args()) :: :ok
  def save_new(task_type, args, extra_args \\ []) do
    if not is_enqueued?(task_type, args) do
      index = {System.system_time(), task_type}
      m_task = Model.async_task(index: index, args: args, extra_args: extra_args)
      Database.dirty_write(Model.AsyncTask, m_task)

      :ets.insert(@args_tab, {{task_type, args}})
    end

    :ok
  end

  @spec set_processing(Model.async_task_index()) :: :ok
  def set_processing(task_index) do
    :ets.insert(@processing_tab, {task_index})
    :ok
  end

  @spec set_done(Model.async_task_index(), Model.async_task_args()) :: :ok
  def set_done({_ts, task_type} = task_index, args) do
    Database.dirty_delete(Model.AsyncTask, task_index)

    :ets.delete_object(@processing_tab, task_index)
    :ets.delete(@args_tab, {task_type, args})
    :ok
  end

  #
  # Private functions
  #
  defp fetch_all() do
    Model.AsyncTask
    |> Database.all_keys()
    |> Enum.map(&Database.fetch!(Model.AsyncTask, &1))
  end

  defp cache_tasks_by_args() do
    indexed_args_records =
      fetch_all()
      |> Enum.map(fn Model.async_task(index: {_ts, task_type}, args: args) ->
        {{task_type, args}}
      end)

    :ets.insert(@args_tab, indexed_args_records)
  end

  defp is_enqueued?(task_type, args) do
    :ets.member(@args_tab, {task_type, args})
  end
end
