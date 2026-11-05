defprotocol AeMdw.Db.Store do
  @moduledoc """
  Abstraction that provides a basic sorted key-value store.
  """

  alias AeMdw.Database

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep table() :: Database.table()

  @spec put(t(), table(), record()) :: t()
  def put(store, table, record)

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(store, table, key)

  @spec delete(t(), table(), key()) :: t()
  def delete(store, table, key)

  @spec next(t(), table(), key() | nil) :: {:ok, key()} | :none
  def next(store, table, key)

  @spec prev(t(), table(), key() | nil) :: {:ok, key()} | :none
  def prev(store, table, key)

  @doc """
  Streams the keys of a table, starting at `start_key` (included when present) or at
  the table's edge when it's `nil`.
  """
  @spec stream(t(), table(), Database.direction(), key() | nil) :: Enumerable.t()
  def stream(store, table, direction, start_key)

  @spec count_keys(t(), table()) :: non_neg_integer()
  def count_keys(store, table)
end

defimpl AeMdw.Db.Store, for: Any do
  def put(%mod{} = store, table, record), do: mod.put(store, table, record)
  def get(%mod{} = store, table, key), do: mod.get(store, table, key)
  def delete(%mod{} = store, table, key), do: mod.delete(store, table, key)
  def next(%mod{} = store, table, key), do: mod.next(store, table, key)
  def prev(%mod{} = store, table, key), do: mod.prev(store, table, key)

  def stream(%mod{} = store, table, direction, start_key),
    do: mod.stream(store, table, direction, start_key)

  def count_keys(%mod{} = store, table), do: mod.count_keys(store, table)
end
