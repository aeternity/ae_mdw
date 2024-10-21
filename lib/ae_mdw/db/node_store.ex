defmodule AeMdw.Db.NodeStore do
  @moduledoc """
  Store implementation with operations reading from the node tables directly.
  """

  alias AeMdw.Db.Model

  require Model

  @derive AeMdw.Db.Store
  defstruct []

  @typep key() :: term()
  @typep record() :: tuple()
  @typep table() :: table()
  @opaque t() :: %__MODULE__{}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec put(t(), table(), record()) :: t()
  def put(_store, _table, _record) do
    raise "Not implemented"
  end

  @spec get(t(), table(), key()) :: {:ok, record()} | :not_found
  def get(_store, table, key) do
    ets_table = Model.record(table)

    case :ets.lookup(ets_table, key) do
      [{^key, record}] -> {:ok, record}
      [] -> :not_found
    end
  end

  @spec delete(t(), table(), key()) :: t()
  def delete(_store, _table, _key) do
    raise "Not implemented"
  end

  @spec next(t(), table(), key() | nil) :: {:ok, key()} | :none
  def next(_store, table, nil) do
    ets_table = Model.record(table)

    case :ets.first(ets_table) do
      :"$end_of_table" -> :none
      key -> {:ok, key}
    end
  end

  def next(_store, table, key_boundary) do
    ets_table = Model.record(table)

    case :ets.next(ets_table, key_boundary) do
      :"$end_of_table" -> :none
      key -> {:ok, key}
    end
  end

  @spec prev(t(), table(), key() | nil) :: {:ok, key()} | :none
  def prev(_store, table, nil) do
    ets_table = Model.record(table)

    case :ets.last(ets_table) do
      :"$end_of_table" -> :none
      key -> {:ok, key}
    end
  end

  def prev(_store, table, key_boundary) do
    ets_table = Model.record(table)

    case :ets.prev(ets_table, key_boundary) do
      :"$end_of_table" -> :none
      key -> {:ok, key}
    end
  end

  @spec count_keys(t(), table()) :: non_neg_integer()
  def count_keys(_store, table) do
    ets_table = Model.record(table)

    :ets.info(ets_table, :size)
  end
end
