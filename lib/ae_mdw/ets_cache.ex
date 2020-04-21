defmodule AeMdw.EtsCache do

  require Ex2ms

  ################################################################################

  def init(name, expiration_minutes) do
    :ets.new(name, [
          :named_table,
          :public,
          {:read_concurrency, true},
          {:write_concurrency, true}
        ])
    gc_period = :timer.minutes(expiration_minutes)
    {:ok, _} = :timer.apply_interval(gc_period, __MODULE__, :purge, [name, gc_period])
  end

  def put(table, key, val),
    do: :ets.insert(table, {key, val, time()})

  def get(table, key) do
    case :ets.lookup(table, key) do
      [{_, val, insert_time}] ->
        {val, insert_time}
      [] ->
        nil
    end
  end

  def purge(table, max_age_msecs) do
    boundary = time() - max_age_msecs

    del_spec =
      Ex2ms.fun do
        {_, _, time} -> time < ^boundary
      end

    :ets.select_delete(table, del_spec)
  end

  defp time(),
    do: :os.system_time(:millisecond)

end
