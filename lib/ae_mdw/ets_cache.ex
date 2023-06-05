defmodule AeMdw.EtsCache do
  @moduledoc false

  require Ex2ms

  @type table() :: atom()
  @type expiration() :: non_neg_integer()
  @type type() :: :set | :ordered_set | :bag | :duplicate_bag
  @type access() :: :public | :private | :protected
  @type concurrency?() :: boolean()
  @type key() :: term()
  @type val() :: term()

  @spec new(table(), expiration(), type(), access(), concurrency?()) :: :ok
  def new(name, expiration_minutes, type \\ :set, access \\ :public, concurrency? \\ true) do
    params =
      ((name && [:named_table]) || []) ++
        [{:read_concurrency, concurrency?}, {:write_concurrency, concurrency?}, access, type]

    table = :ets.new(name, params)
    init_gc(table, expiration_minutes)

    :ok
  end

  @spec put(table(), key(), val()) :: true
  def put(table, key, val), do: :ets.insert(table, {key, val, time()})

  @spec all(table()) :: [tuple()]
  def all(table), do: :ets.tab2list(table)

  @spec get(table(), key()) :: {val(), integer()} | nil
  def get(table, key) do
    case :ets.lookup(table, key) do
      [{_, val, insert_time}] ->
        {val, insert_time}

      [] ->
        nil
    end
  end

  @spec del(table(), key()) :: true
  def del(table, key),
    do: :ets.delete(table, key)

  @spec member(table(), key()) :: boolean()
  def member(table, key),
    do: :ets.member(table, key)

  @spec next(table(), key()) :: key() | nil
  def next(table, key) do
    case :ets.next(table, key) do
      :"$end_of_table" -> nil
      next_key -> next_key
    end
  end

  @spec prev(table(), key()) :: key() | nil
  def prev(table, key) do
    case :ets.prev(table, key) do
      :"$end_of_table" -> nil
      prev_key -> prev_key
    end
  end

  @spec clear(table()) :: true
  def clear(table), do: :ets.delete_all_objects(table)

  @spec purge(table(), expiration()) :: non_neg_integer()
  def purge(table, max_age_msecs) do
    boundary = time() - max_age_msecs

    del_spec =
      Ex2ms.fun do
        {_key, _val, time} -> time < ^boundary
      end

    :ets.select_delete(table, del_spec)
  end

  defp time(),
    do: :os.system_time(:millisecond)

  defp init_gc(_table, exp) when exp in [nil, :infinity], do: :ok

  defp init_gc(table, exp) when is_integer(exp) and exp > 0 do
    gc_period = :timer.minutes(exp)
    {:ok, _ref} = :timer.apply_interval(gc_period, __MODULE__, :purge, [table, gc_period])
    :ok
  end
end
