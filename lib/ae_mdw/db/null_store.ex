defmodule AeMdw.Db.NullStore do
  @moduledoc """
  Empty store implementation for testing purposes.
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
  def put(store, _table, _record), do: store

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(_store, _table, _key), do: :not_found

  @spec delete(t(), table(), key()) :: t()
  def delete(store, _table, _key), do: store

  @spec count_keys(t(), table()) :: non_neg_integer()
  def count_keys(_store, _table), do: 0

  @spec next(t(), table(), key() | nil) :: {:ok, key()} | :none
  def next(_store, _table, _key), do: :none

  @spec prev(t(), table(), key() | nil) :: {:ok, key()} | :none
  def prev(_store, _table, _key), do: :none
end
