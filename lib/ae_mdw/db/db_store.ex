defmodule AeMdw.Db.DbStore do
  @moduledoc """
  Store implementation with operations reading/writing on the database directly,
  without the need for a transaction.
  """

  alias AeMdw.Database

  @derive AeMdw.Db.Store
  defstruct []

  @typep key() :: Database.key()
  @typep record() :: Database.record()
  @typep table() :: Database.table()
  @opaque t() :: %__MODULE__{}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec put(t(), table(), record()) :: t()
  def put(store, table, record) do
    Database.dirty_write(table, record)

    store
  end

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(_store, table, key), do: Database.get(table, key)

  @spec delete(t(), table(), key()) :: t()
  def delete(store, table, key) do
    Database.dirty_delete(table, key)

    store
  end

  @spec next(t(), table(), key() | nil) :: {:ok, key()} | :none
  def next(_store, table, nil), do: Database.first_key(table)

  def next(_store, table, key_boundary), do: Database.next_key(table, key_boundary)

  @spec prev(t(), table(), key() | nil) :: {:ok, key()} | :none
  def prev(_store, table, nil), do: Database.last_key(table)

  def prev(_store, table, key_boundary), do: Database.prev_key(table, key_boundary)

  @spec count_keys(t(), table()) :: non_neg_integer()
  def count_keys(_store, table), do: Database.count(table)
end
