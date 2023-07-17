defmodule AeMdw.Db.MemStore do
  @moduledoc """
  Store implementation with operations reading/writing in-memory.

  Uses a SortedTable for hashed access to the keys, plus, being able to
  iterate over them both forwards and backwards.

  Fallbacks to a different Store implementation that can be configured when
  building this store.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Util.SortedTable

  @derive AeMdw.Db.Store
  defstruct [:fallback_store, :tables]

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep table() :: Database.table()
  @opaque t() :: %__MODULE__{
            fallback_store: Store.t(),
            tables: %{table() => SortedTable.t()}
          }

  @spec new(Store.t()) :: t()
  def new(store), do: %__MODULE__{fallback_store: store, tables: new_tables()}

  @spec delete_store(t()) :: :ok
  def delete_store(%__MODULE__{tables: tables}),
    do: Enum.each(tables, fn {_name, t} -> SortedTable.delete(t) end)

  @spec put(t(), table(), record()) :: t()
  def put(%__MODULE__{tables: tables} = store, table_name, record) do
    key = elem(record, 1)

    table =
      tables
      |> get_table(table_name)
      |> SortedTable.insert(key, {:added, record})

    %__MODULE__{store | tables: Map.put(tables, table_name, table)}
  end

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(%__MODULE__{tables: tables, fallback_store: fallback_store}, table, key) do
    case SortedTable.lookup(get_table(tables, table), key) do
      {:ok, {:added, record}} -> {:ok, record}
      {:ok, :deleted} -> :not_found
      :not_found -> Store.get(fallback_store, table, key)
    end
  end

  @spec delete(t(), table(), key()) :: t()
  def delete(%__MODULE__{tables: tables} = store, table_name, key) do
    table = get_table(tables, table_name)

    table2 =
      case SortedTable.lookup(table, key) do
        {:ok, {:added, _record}} -> SortedTable.delete(table, key)
        _deleted_or_not_found -> SortedTable.insert(table, key, :deleted)
      end

    %__MODULE__{store | tables: Map.put(tables, table_name, table2)}
  end

  @spec count_keys(t(), table()) :: non_neg_integer()
  def count_keys(%__MODULE__{tables: tables, fallback_store: fallback_store}, table_name) do
    count_db = Store.count_keys(fallback_store, table_name)

    count_mem =
      tables
      |> get_table(table_name)
      |> SortedTable.stream_forward()
      |> Enum.reduce(0, fn {key, value}, count ->
        new_key? = :not_found == Store.get(fallback_store, table_name, key)

        cond do
          value == :deleted and not new_key? ->
            count - 1

          value != :deleted and new_key? ->
            count + 1

          true ->
            count
        end
      end)

    count_db + count_mem
  end

  @spec next(t(), table(), key() | nil) :: {:ok, key()} | :none
  def next(%__MODULE__{fallback_store: fallback_store, tables: tables} = store, table, key) do
    case {Store.next(fallback_store, table, key), SortedTable.next(get_table(tables, table), key)} do
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
    case {Store.prev(fallback_store, table, key), SortedTable.prev(get_table(tables, table), key)} do
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

  defp get_table(tables, table_name), do: Map.fetch!(tables, table_name)

  defp new_tables() do
    Map.new(Model.column_families(), fn table_name ->
      {table_name, SortedTable.new()}
    end)
  end
end
