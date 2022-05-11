defmodule AeMdw.Db.MemStore do
  @moduledoc """
  Store implementation with operations reading/writing in-memory.

  Uses a GbTree implementation for fast access to the keys, plus, being able to
  iterate over them both forwards and backwards.

  Fallbacks to a different Store implementation that can be configured when
  building this store.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Store
  alias AeMdw.Util.GbTree

  @derive AeMdw.Db.Store
  defstruct [:fallback_store, :tables]

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep table() :: Database.table()
  @opaque t() :: %__MODULE__{
            fallback_store: Store.t(),
            tables: %{table() => GbTree.t()}
          }

  @spec new(Store.t()) :: t()
  def new(store), do: %__MODULE__{fallback_store: store, tables: %{}}

  @spec put(t(), table(), record()) :: t()
  def put(%__MODULE__{tables: tables} = store, table, record) do
    key = elem(record, 1)
    new_tables = insert_or_update(tables, table, key, {:added, record})

    %__MODULE__{store | tables: new_tables}
  end

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(%__MODULE__{tables: tables, fallback_store: fallback_store}, table, key) do
    case GbTree.lookup(get_tree(tables, table), key) do
      {:ok, {:added, record}} -> {:ok, record}
      {:ok, :deleted} -> :not_found
      :not_found -> Store.get(fallback_store, table, key)
    end
  end

  @spec delete(t(), table(), key()) :: t()
  def delete(%__MODULE__{tables: tables} = store, table, key) do
    tree = get_tree(tables, table)

    tree2 =
      case GbTree.lookup(tree, key) do
        {:ok, {:added, _record}} -> GbTree.delete(tree, key)
        _deleted_or_not_found -> GbTree.insert(tree, key, :deleted)
      end

    %__MODULE__{store | tables: Map.put(tables, table, tree2)}
  end

  @spec count_keys(t(), table()) :: non_neg_integer()
  def count_keys(%__MODULE__{tables: tables, fallback_store: fallback_store}, table) do
    count = Store.count_keys(fallback_store, table)

    case Map.fetch(tables, table) do
      {:ok, tab} ->
        tab
        |> GbTree.stream_forward()
        |> Enum.reduce(count, fn
          {_key, {:added, _record}}, count -> count + 1
          {_key, :deleted}, count -> count - 1
        end)

      :error ->
        count
    end
  end

  @spec next(t(), table(), key() | nil) :: {:ok, key()} | :none
  def next(%__MODULE__{fallback_store: fallback_store, tables: tables} = store, table, key) do
    case {Store.next(fallback_store, table, key), GbTree.next(get_tree(tables, table), key)} do
      {:none, :none} -> :none
      {{:ok, key}, :none} -> {:ok, key}
      {:none, {:ok, key, :deleted}} -> next(store, table, key)
      {:none, {:ok, key, {:added, _record}}} -> {:ok, key}
      {{:ok, key}, {:ok, key, :deleted}} -> next(store, table, key)
      {{:ok, key1}, {:ok, key2, :deleted}} when key1 < key2 -> {:ok, key1}
      {{:ok, key1}, {:ok, key2, :deleted}} when key1 > key2 -> next(store, table, key2)
      {{:ok, key1}, {:ok, key2, {:added, _record}}} -> {:ok, min(key1, key2)}
    end
  end

  @spec prev(t(), table(), key() | nil) :: {:ok, key()} | :none
  def prev(%__MODULE__{fallback_store: fallback_store, tables: tables} = store, table, key) do
    case {Store.prev(fallback_store, table, key), GbTree.prev(get_tree(tables, table), key)} do
      {:none, :none} -> :none
      {{:ok, key}, :none} -> {:ok, key}
      {:none, {:ok, key, :deleted}} -> prev(store, table, key)
      {:none, {:ok, key, {:added, _record}}} -> {:ok, key}
      {{:ok, key}, {:ok, key, :deleted}} -> prev(store, table, key)
      {{:ok, key1}, {:ok, key2, :deleted}} when key2 < key1 -> {:ok, key1}
      {{:ok, key1}, {:ok, key2, :deleted}} when key2 > key1 -> prev(store, table, key2)
      {{:ok, key1}, {:ok, key2, {:added, _record}}} -> {:ok, max(key1, key2)}
    end
  end

  defp get_tree(tables, table), do: Map.get(tables, table, GbTree.new())

  defp insert_or_update(tables, table, key, value) do
    table2 =
      tables
      |> Map.get(table, GbTree.new())
      |> GbTree.insert(key, value)

    Map.put(tables, table, table2)
  end
end
