defmodule AeMdw.Sync.AsyncTasks.Store do
  @moduledoc """
  Read-write access for async tasks persistent data and cache for processing state.
  """

  alias AeMdw.Db.Model
  # alias AeMdw.Mnesia
  # alias AeMdw.Db.Util
  alias AeMdw.Log

  require Ex2ms
  require Log
  require Model

  @typep task_index() :: {pos_integer(), atom()}
  @eot :"$end_of_table"

  @max_buffer_size 10

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
    # {m_tasks, _cont} = Util.select(Model.AsyncTasks, Ex2ms.fun do record -> record end, @max_buffer_size)
    safe_fetch()
    |> Enum.filter(fn Model.async_tasks(index: index) ->
      not :ets.member(:async_tasks_processing, index)
    end)
  end

  @spec save_new(atom(), list()) :: :ok
  def save_new(task_type, args) do
    :mnesia.sync_transaction(fn ->
      exists_spec =
        Ex2ms.fun do
          {:_, {:_, ^task_type}, ^args} -> true
        end

      case :mnesia.select(Model.AsyncTasks, exists_spec, 1, :read) do
        {[], _cont} ->
          index = {System.system_time(), task_type}
          m_task = Model.async_tasks(index: index, args: args)
          :mnesia.write(Model.AsyncTasks, m_task, :write)

        _existing ->
          :noop
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
  defp safe_fetch do
    fn ->
      case :mnesia.first(Model.AsyncTasks) do
        @eot -> []
        first_key ->
          Stream.unfold({@max_buffer_size, first_key}, fn
            {0, _current_key} ->
              nil
            {n, current_key} ->
              case :mnesia.next(Model.AsyncTasks, current_key) do
                @eot -> nil
                next_key ->
                  {
                    :mnesia.read(Model.AsyncTasks, current_key),
                    {n-1, next_key}
                  }
              end
          end)
      end
    end
    |> :mnesia.transaction()
    |> case do
      {:atomic, m_tasks} -> m_tasks
      _error -> []
    end
  end

  # defp safe_fetch() do
  #   fn ->
  #     record_spec =
  #       Ex2ms.fun do
  #         record -> record
  #       end

  #     :mnesia.select(Model.AsyncTasks, record_spec, @max_buffer_size, :read)
  #   end
  #   |> :mnesia.transaction()
  #   |> case do
  #     {:atomic, {m_tasks, _cont}} ->
  #       m_tasks

  #     {:aborted, reason} ->
  #       Log.warn("AsyncTasks fetch aborted due to #{inspect(reason)}")
  #       []
  #   end
  # end
end
