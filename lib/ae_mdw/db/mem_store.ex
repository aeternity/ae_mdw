defmodule AeMdw.Db.MemStore do
  @moduledoc """
  Store implementation with operations reading/writing in-memory.

  Uses a SortedTable for hashed access to the keys, plus, being able to
  iterate over them both forwards and backwards.

  Fallbacks to a different Store implementation that can be configured when
  building this store.
  """

  alias AeMdw.Db.NullStore
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Util.SortedTable

  @derive AeMdw.Db.Store
  defstruct [:fallback_store, :tables]

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep table() :: Database.table()
  @typep direction() :: Database.direction()
  @opaque t() :: %__MODULE__{
            fallback_store: Store.t(),
            tables: %{table() => SortedTable.t()}
          }

  @spec new(Store.t()) :: t()
  def new(store), do: %__MODULE__{fallback_store: store, tables: new_tables()}

  @spec delete_store(t()) :: :ok
  def delete_store(%__MODULE__{tables: tables}),
    do: Enum.each(tables, fn {_name, t} -> SortedTable.delete(t) end)

  @spec without_fallback(t()) :: t()
  def without_fallback(%{tables: tables}),
    do: %__MODULE__{fallback_store: NullStore.new(), tables: tables}

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

  @doc """
  Merges the fallback store's keys with the in-memory ones. The in-memory table is read
  again for every key since the stream's consumer may change it meanwhile.
  """
  @spec stream(t(), table(), direction(), key() | nil) :: Enumerable.t()
  def stream(
        %__MODULE__{fallback_store: fallback_store, tables: tables},
        table_name,
        direction,
        start_key
      ) do
    table = get_table(tables, table_name)
    fallback_keys = Store.stream(fallback_store, table_name, direction, start_key)

    Stream.resource(
      fn ->
        fallback =
          pull_key(fn acc -> Enumerable.reduce(fallback_keys, acc, &suspend_key/2) end)

        {{:from, start_key}, fallback}
      end,
      &merge_next(table, direction, &1),
      fn {_mem_from, fallback} -> halt_keys(fallback) end
    )
  end

  defp merge_next(table, direction, {mem_from, {:pull, cont}}),
    do: merge_next(table, direction, {mem_from, pull_key(cont)})

  defp merge_next(table, direction, {mem_from, fallback} = acc) do
    case {fallback, mem_entry(table, direction, mem_from)} do
      {:none, :none} ->
        {:halt, acc}

      {{:ok, fallback_key, cont}, :none} ->
        {[fallback_key], {{:after, fallback_key}, {:pull, cont}}}

      {:none, {:ok, key, value}} ->
        {live_keys(key, value), {{:after, key}, :none}}

      {{:ok, fallback_key, cont}, {:ok, key, value}} ->
        cond do
          before?(fallback_key, key, direction) ->
            {[fallback_key], {{:after, fallback_key}, {:pull, cont}}}

          before?(key, fallback_key, direction) ->
            {live_keys(key, value), {{:after, key}, fallback}}

          true ->
            {live_keys(key, value), {{:after, key}, {:pull, cont}}}
        end
    end
  end

  defp mem_entry(table, direction, {:from, key}) do
    case SortedTable.lookup(table, key) do
      {:ok, value} -> {:ok, key, value}
      :not_found -> mem_entry(table, direction, {:after, key})
    end
  end

  defp mem_entry(table, :forward, {:after, key}), do: SortedTable.next(table, key)
  defp mem_entry(table, :backward, {:after, key}), do: SortedTable.prev(table, key)

  defp live_keys(_key, :deleted), do: []
  defp live_keys(key, {:added, _record}), do: [key]

  defp before?(key1, key2, :forward), do: key1 < key2
  defp before?(key1, key2, :backward), do: key1 > key2

  defp pull_key(cont) do
    case cont.({:cont, nil}) do
      {:suspended, key, cont} -> {:ok, key, cont}
      {_done_or_halted, nil} -> :none
    end
  end

  defp suspend_key(key, nil), do: {:suspend, key}

  defp halt_keys({:ok, _key, cont}), do: cont.({:halt, nil})
  defp halt_keys({:pull, cont}), do: cont.({:halt, nil})
  defp halt_keys(:none), do: :ok

  defp get_table(tables, table_name), do: Map.fetch!(tables, table_name)

  defp new_tables() do
    Map.new(Model.tables(), fn table_name ->
      {table_name, SortedTable.new()}
    end)
  end
end
