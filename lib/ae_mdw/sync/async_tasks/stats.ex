defmodule AeMdw.Sync.AsyncTasks.Stats do
  @moduledoc """
  Stats of AsyncTasks processing.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util

  require Model

  @tab :async_tasks_stats
  @stats_key :async_tasks_stats_key
  @max_db_count_times 10

  @spec init() :: :ok
  def init do
    :ets.new(@tab, [:named_table, :set, :public])
    :ets.insert(@tab, {@stats_key, 0, 0})
    :ok
  end

  @spec update(pos_integer(), pos_integer()) :: :ok
  def update(producer_buffer_len, max_len) do
    :ets.update_element(@tab, @stats_key, {2, producer_buffer_len})

    cond do
      producer_buffer_len == 0 -> reset_db_count()
      rem(max_len, @max_db_count_times) == 0 -> update_db_count()
      true -> :noop
    end

    :ok
  end

  @spec counters() :: map()
  def counters do
    [{@stats_key, producer_buffer_len, db_pending_count}] = :ets.lookup(@tab, @stats_key)

    %{
      producer_buffer: producer_buffer_len,
      total_pending: db_pending_count,
    }
  end

  #
  # Private functions
  #
  defp update_db_count() do
    db_pending_count = :mnesia.async_dirty(fn -> Util.count(Model.AsyncTasks) end)
    :ets.update_element(@tab, @stats_key, {3, db_pending_count})
  end

  defp reset_db_count() do
    :ets.update_element(@tab, @stats_key, {3, 0})
  end
end
