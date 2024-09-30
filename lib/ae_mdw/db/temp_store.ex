defmodule AeMdw.Db.TempStore do
  @moduledoc """
  Store implementation with operations reading/writing in-memory.

  Used to store temporary data before it is written to the main store.
  """
  alias AeMdw.Database
  alias AeMdw.Db.WriteMutation

  @derive AeMdw.Db.Store
  defstruct [:tables]

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep table() :: Database.table()

  @opaque t() :: %__MODULE__{}

  @spec new() :: t()
  def new, do: %__MODULE__{tables: %{}}

  @spec put(t(), table(), record()) :: t()
  def put(%__MODULE__{tables: tables}, table, record) do
    key = elem(record, 1)
    store_table = Map.get(tables, table, :gb_trees.empty())
    store_table = :gb_trees.enter(key, record, store_table)
    %__MODULE__{tables: Map.put(tables, table, store_table)}
  end

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(%__MODULE__{tables: tables}, table, key) do
    store_table = Map.get(tables, table, :gb_trees.empty())

    case :gb_trees.lookup(key, store_table) do
      {:value, record} -> {:ok, record}
      :none -> :not_found
    end
  end

  @spec delete(t(), table(), key()) :: t()
  def delete(%__MODULE__{tables: tables}, table, key) do
    store_table = Map.get(tables, table, :gb_trees.empty())
    store_table = :gb_trees.delete_any(key, store_table)
    %__MODULE__{tables: Map.put(tables, table, store_table)}
  end

  @spec count_keys(t(), table()) :: non_neg_integer()
  def count_keys(%__MODULE__{tables: tables}, table) do
    store_table = Map.get(tables, table, :gb_trees.empty())
    :gb_trees.size(store_table)
  end

  @spec next(t(), table(), key() | nil) :: {:ok, key()} | :none
  def next(%__MODULE__{tables: tables}, table, key) do
    store_table = Map.get(tables, table, :gb_trees.empty())
    iterator = :gb_trees.iterator_from(key, store_table)

    with {next_key, _value, next_iterator} <- :gb_trees.next(iterator),
         {true, _next_key} <- {next_key == key, next_key},
         {actual_next_key, _value, _next_iterator} <- :gb_trees.next(next_iterator) do
      {:ok, actual_next_key}
    else
      {false, next_key} -> {:ok, next_key}
      :none -> :none
    end
  end

  @spec prev(t(), table(), key() | nil) :: {:ok, key()} | :none
  def prev(_store, _table, _key) do
    raise "Not implemented"
  end

  @spec to_mutations(t()) :: Enumerable.t()
  def to_mutations(%__MODULE__{tables: tables}) do
    tables
    |> Stream.flat_map(fn {table, store_table} ->
      Stream.resource(
        fn -> :gb_trees.iterator(store_table) end,
        fn it ->
          case :gb_trees.next(it) do
            {_key, record, next_it} -> {[WriteMutation.new(table, record)], next_it}
            :none -> {:halt, nil}
          end
        end,
        fn _it -> :ok end
      )
    end)
  end
end
