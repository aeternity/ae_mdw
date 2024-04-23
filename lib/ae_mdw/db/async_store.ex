defmodule AeMdw.Db.AsyncStore do
  @moduledoc """
  Implementation of Store protocol to be used by asynchronous tasks.

  Its operations have immediate in-memory effect (not persisted) and
  is backed by a cache with TTL of 1 day.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Mutation
  alias AeMdw.EtsCache

  @derive AeMdw.Db.Store
  defstruct tid: nil

  @table_id :single_async_store
  @ttl_minutes 24 * 60

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep table() :: Database.table()
  @opaque t() :: %__MODULE__{tid: :single_async_store}

  @spec init(atom()) :: :ok
  def init(t_id \\ @table_id) do
    EtsCache.new(t_id, @ttl_minutes, :ordered_set)
    :ok
  end

  @spec instance(atom()) :: t()
  def instance(t_id \\ @table_id) do
    %__MODULE__{tid: t_id}
  end

  @spec mutations(t()) :: [Mutation.t()]
  def mutations(%__MODULE__{tid: tid}) do
    tid
    |> EtsCache.all()
    |> Enum.map(fn {{table, _key}, record, _time} ->
      AeMdw.Db.WriteMutation.new(table, record)
    end)
  end

  @spec put(t(), table(), record()) :: t()
  def put(%__MODULE__{tid: tid} = store, table, record) do
    EtsCache.put(tid, {table, elem(record, 1)}, record)

    store
  end

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(%__MODULE__{tid: tid}, table, key) do
    case EtsCache.get(tid, {table, key}) do
      {record, _time} -> {:ok, record}
      nil -> :not_found
    end
  end

  @spec delete(t(), table(), key()) :: t()
  def delete(%__MODULE__{tid: tid} = store, table, key) do
    EtsCache.del(tid, {table, key})

    store
  end

  @spec next(t(), table(), key() | nil) :: {:ok, key()} | :none
  def next(%__MODULE__{tid: tid}, table, key) do
    case EtsCache.next(tid, {table, key}) do
      {^table, next_key} -> {:ok, next_key}
      _not_found_or_mismatch -> :none
    end
  end

  @spec prev(t(), table(), key() | nil) :: {:ok, key()} | :none
  def prev(%__MODULE__{tid: tid}, table, key) do
    case EtsCache.prev(tid, {table, key}) do
      {^table, prev_key} -> {:ok, prev_key}
      _not_found_or_mismatch -> :none
    end
  end

  @spec count_keys(t(), table()) :: non_neg_integer()
  def count_keys(%__MODULE__{tid: tid}, table) do
    do_count_keys(tid, table, nil, 0)
  end

  defp do_count_keys(tid, table, key, count) do
    case EtsCache.next(tid, {table, key}) do
      {^table, next_key} -> do_count_keys(tid, table, next_key, count + 1)
      _other_table_or_nil -> count
    end
  end

  @spec clear(t()) :: :ok
  def clear(%__MODULE__{tid: tid}) do
    EtsCache.clear(tid)
    :ok
  end
end
