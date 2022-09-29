defmodule AeMdw.Sync.AsyncTasks.Store do
  @moduledoc """
  Read-write access for async tasks persistent data and cache for processing state.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.EtsCache

  require Ex2ms
  require Model

  @type pending_key :: {Model.async_task_type(), Model.async_task_args()}

  @added_tab :async_tasks_added
  @pending_tab :async_tasks_pending
  @processing_tab :async_tasks_processing

  @minutes_expire 60

  @spec init() :: :ok
  def init do
    EtsCache.new(@added_tab, @minutes_expire)
    @pending_tab = :ets.new(@pending_tab, [:named_table, :ordered_set, :public])
    @processing_tab = :ets.new(@processing_tab, [:named_table, :set, :public])
    :ok
  end

  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(@processing_tab)
    cache_tasks_by_args()
    :ok
  end

  @spec add(Model.async_task_record(), only_new: boolean()) :: :ok
  def add(Model.async_task(index: task_index) = m_task, only_new: only_new) do
    key1 = pending_key(m_task)
    key2 = added_key(m_task)

    insert? =
      if only_new do
        not is_enqueued?(key1) and not is_added?(key2)
      else
        not is_enqueued?(key1)
      end

    if insert? do
      :ets.insert(@pending_tab, {key1, m_task})
      EtsCache.put(@added_tab, key2, task_index)
    end

    :ok
  end

  @spec next_unprocessed(pending_key() | {nil, nil}) :: Model.async_task_record() | nil
  def next_unprocessed(next_key \\ {nil, nil}) do
    case :ets.next(@pending_tab, next_key) do
      :"$end_of_table" ->
        nil

      key ->
        case set_processing(key) do
          {:ok, m_task} -> m_task
          :error -> next_unprocessed(key)
        end
    end
  end

  @spec count_unprocessed :: non_neg_integer()
  def count_unprocessed do
    :ets.info(@pending_tab, :size) - :ets.info(@processing_tab, :size)
  end

  @spec save() :: :ok
  def save do
    list_pending_tasks()
    |> Enum.each(fn Model.async_task(index: key) = m_task ->
      if not Database.exists?(Model.AsyncTask, key) do
        Database.dirty_write(Model.AsyncTask, m_task)
      end
    end)

    :ok
  end

  @spec set_processing(pending_key() | {nil, nil}) :: {:ok, Model.async_task_record()} | :error
  def set_processing(pending_key) do
    case :ets.lookup(@pending_tab, pending_key) do
      [{_key, Model.async_task(index: task_index) = m_task}] ->
        if 1 == :ets.update_counter(@processing_tab, task_index, {2, 1}, {task_index, 0}) do
          {:ok, m_task}
        else
          :error
        end

      [] ->
        :error
    end
  end

  @spec set_unprocessed(Model.async_task_index()) :: :ok
  def set_unprocessed(task_index) do
    :ets.delete(@processing_tab, task_index)
    :ok
  end

  @spec set_done(Model.async_task_index(), Model.async_task_args()) :: :ok
  def set_done({_ts, task_type} = task_index, args) do
    Database.dirty_delete(Model.AsyncTask, task_index)
    :ets.delete(@processing_tab, task_index)
    :ets.delete(@pending_tab, {task_type, args})

    :ok
  end

  #
  # Private functions
  #
  defp list_pending_tasks() do
    @pending_tab
    |> :ets.tab2list()
    |> Enum.map(fn {_key, m_task} -> m_task end)
    |> Enum.sort_by(fn Model.async_task(index: index) -> index end)
  end

  defp fetch_persisted_tasks() do
    Model.AsyncTask
    |> Database.all_keys()
    |> Enum.flat_map(fn key ->
      case Database.fetch(Model.AsyncTask, key) do
        {:ok, m_task} -> [m_task]
        :not_found -> []
      end
    end)
  end

  defp cache_tasks_by_args() do
    indexed_args_records =
      fetch_persisted_tasks()
      |> Enum.map(fn m_task ->
        {pending_key(m_task), m_task}
      end)

    :ets.insert(@pending_tab, indexed_args_records)
  end

  defp pending_key(Model.async_task(index: {_ts, task_type}, args: args)), do: {task_type, args}

  defp added_key(Model.async_task(index: {_ts, task_type}, args: args, extra_args: extra_args)),
    do: {task_type, args, extra_args}

  defp is_enqueued?({_task_type, _args} = key) do
    :ets.member(@pending_tab, key)
  end

  defp is_added?({_task_type, _args, _extra_args} = key) do
    EtsCache.member(@added_tab, key)
  end
end
