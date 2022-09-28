defmodule AeMdw.Sync.AsyncTasks.Stats do
  @moduledoc """
  Stats of AsyncTasks processing.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model

  require Model

  @tab :async_tasks_stats
  @stats_key :async_tasks_stats_key
  @max_db_count_times 10

  @buffer_len_pos 2
  @db_count_pos 3

  @spec init() :: :ok
  def init do
    @tab = :ets.new(@tab, [:named_table, :set, :public])
    :ets.insert(@tab, {@stats_key, 0, 0, 0})
    :ok
  end

  @spec update_buffer_len(pos_integer()) :: :ok
  def update_buffer_len(producer_buffer_len) do
    len = max(0, producer_buffer_len)
    :ets.update_element(@tab, @stats_key, {@buffer_len_pos, len})

    if rem(len, @max_db_count_times) == 0, do: update_db_count()

    :ok
  end

  @spec update_consumed() :: :ok
  def update_consumed do
    dec_db_count()

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

  defp update_db_count() do
    db_pending_count = Database.count(Model.AsyncTask)
    :ets.update_element(@tab, @stats_key, {@db_count_pos, db_pending_count})
  end
end
