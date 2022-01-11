defmodule AeMdw.Sync.AsyncTasks.Store do
  @moduledoc """
  Read-write access for async tasks persistent data and cache for processing state.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.Util

  require Ex2ms
  require Model

  @type task_index() :: {pos_integer(), atom()}
  @type task_args() :: list()

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

  @spec fetch_unprocessed(pos_integer()) :: [Model.async_tasks_record()]
  def fetch_unprocessed(max_amount) do
    any_spec =
      Ex2ms.fun do
        record -> record
      end

    {m_tasks, _cont} = Util.select(Model.AsyncTasks, any_spec, max_amount)

    Enum.filter(m_tasks, fn Model.async_tasks(index: index) ->
      not :ets.member(@processing_tab, index)
    end)
  end

  @spec save_new(atom(), list()) :: :ok
  def save_new(task_type, args) do
    :mnesia.sync_transaction(fn ->
      if not is_enqueued?(task_type, args) do
        index = {System.system_time(), task_type}
        m_task = Model.async_tasks(index: index, args: args)
        :mnesia.write(Model.AsyncTasks, m_task, :write)
        :ets.insert(@args_tab, {{task_type, args}})
      end
    end)

    :ok
  end

  @spec set_processing(task_index()) :: :ok
  def set_processing(task_index) do
    :ets.insert(@processing_tab, {task_index})
    :ok
  end

  @spec set_done(task_index(), task_args()) :: :ok
  def set_done({_ts, task_type} = task_index, args) do
    :mnesia.sync_transaction(fn ->
      :mnesia.delete(Model.AsyncTasks, task_index, :write)
    end)

    :ets.delete_object(@processing_tab, task_index)
    :ets.delete(@args_tab, {task_type, args})
    :ok
  end

  #
  # Private functions
  #
  def cache_tasks_by_args() do
    {:atomic, indexed_args_records} =
      :mnesia.transaction(fn ->
        args_spec =
          Ex2ms.fun do
            Model.async_tasks(index: {_ts, task_type}, args: args) -> {{task_type, args}}
          end

        :mnesia.select(Model.AsyncTasks, args_spec)
      end)

    :ets.insert(@args_tab, indexed_args_records)
  end

  defp is_enqueued?(task_type, args) do
    :ets.member(@args_tab, {task_type, args})
  end
end
