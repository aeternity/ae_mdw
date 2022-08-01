defmodule AeMdw.EtsCache do
  # credo:disable-for-this-file
  @moduledoc false

  require Ex2ms

  @cache_types [:set, :ordered_set, :bag, :duplicate_bag]
  @cache_access [:public, :private, :protected]

  @type table() :: atom()
  @type expiration() :: non_neg_integer()

  ################################################################################

  def new(name, expiration_minutes, type \\ :set, access \\ :public, concurrency \\ true)
      when is_atom(name) and
             type in @cache_types and
             access in @cache_access and
             is_boolean(concurrency) do
    params =
      ((name && [:named_table]) || []) ++
        [{:read_concurrency, concurrency}, {:write_concurrency, concurrency}, access, type]

    table = :ets.new(name, params)
    init_gc(table, expiration_minutes)
    table
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

  def del(table, key),
    do: :ets.delete(table, key)

  def next(table, key) do
    case :ets.next(table, key) do
      :"$end_of_table" -> nil
      next_key -> next_key
    end
  end

  def prev(table, key) do
    case :ets.prev(table, key) do
      :"$end_of_table" -> nil
      prev_key -> prev_key
    end
  end

  def clear(table), do: :ets.delete_all_objects(table)

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

  defp init_gc(_table, exp) when exp in [nil, :infinity], do: :ok

  defp init_gc(table, exp) when is_integer(exp) and exp > 0 do
    gc_period = :timer.minutes(exp)
    {:ok, _} = :timer.apply_interval(gc_period, __MODULE__, :purge, [table, gc_period])
  end
end
