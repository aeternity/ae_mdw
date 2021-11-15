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

  @buffer_len_pos 2
  @db_count_pos 3
  @long_count_pos 4

  @spec init() :: :ok
  def init do
    :ets.new(@tab, [:named_table, :set, :public])
    :ets.insert(@tab, {@stats_key, 0, 0, 0})
    :ok
  end

  @spec update_buffer_len(pos_integer(), pos_integer()) :: :ok
  def update_buffer_len(producer_buffer_len, max_len) do
    :ets.update_element(@tab, @stats_key, {@buffer_len_pos, producer_buffer_len})

    cond do
      producer_buffer_len == 0 -> reset_db_count()
      rem(max_len, @max_db_count_times) == 0 -> update_db_count()
      true -> :noop
    end

    :ok
  end

  @spec update_consumed(boolean()) :: :ok
  def update_consumed(is_long?) do
    dec_db_count()
    if is_long?, do: dec_long_tasks_count()

    :ok
  end

  @spec inc_long_tasks_count() :: :ok
  def inc_long_tasks_count() do
    :ets.update_counter(@tab, @stats_key, {@long_count_pos, 1, 0, 0})
    :ok
  end

  @spec counters() :: map()
  def counters do
    [{@stats_key, producer_buffer_len, db_pending_count, long_count}] =
      :ets.lookup(@tab, @stats_key)

    %{
      producer_buffer: producer_buffer_len,
      long_tasks: long_count,
      total_pending: db_pending_count
    }
  end

  #
  # Private functions
  #
  defp dec_db_count() do
    :ets.update_counter(@tab, @stats_key, {@db_count_pos, -1, 0, 0})
  end

  defp dec_long_tasks_count() do
    :ets.update_counter(@tab, @stats_key, {@long_count_pos, -1, 0, 0})
  end

  defp update_db_count() do
    db_pending_count = :mnesia.async_dirty(fn -> Util.count(Model.AsyncTasks) end)
    :ets.update_element(@tab, @stats_key, {@db_count_pos, db_pending_count})
  end

  defp reset_db_count() do
    :ets.update_element(@tab, @stats_key, {@db_count_pos, 0})
  end
end
