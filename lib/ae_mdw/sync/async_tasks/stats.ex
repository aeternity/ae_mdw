defmodule AeMdw.Sync.AsyncTasks.Stats do
  @moduledoc """
  Stats of AsyncTasks processing.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model

  require Model

  @tab :async_tasks_stats
  @stats_key :async_tasks_stats_key

  @buffer_len_pos 2

  @spec init() :: :ok
  def init do
    @tab = :ets.new(@tab, [:named_table, :set, :public])
    :ets.insert(@tab, {@stats_key, 0})
    :ok
  end

  @spec update_buffer_len(pos_integer()) :: :ok
  def update_buffer_len(producer_buffer_len) do
    len = max(0, producer_buffer_len)
    :ets.update_element(@tab, @stats_key, {@buffer_len_pos, len})

    :ok
  end

  @spec counters() :: map()
  def counters do
    [{@stats_key, producer_buffer_len}] = :ets.lookup(@tab, @stats_key)
    db_pending_count = Database.count(Model.AsyncTask)

    %{
      producer_buffer: producer_buffer_len,
      long_tasks: 0,
      total_pending: db_pending_count
    }
  end
end
