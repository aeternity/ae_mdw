defmodule AeMdw.Database do
  @moduledoc """
  Database wrapper to provide a simpler API.

  In order to iterate throught collections of records we use the
  concept of "cursor". A cursor is just a key of any given table that
  is returned in order the access the next page of records.

  This cursor key is whatever the current key of the table might be
  (e.g. a tuple, a number). If there is no next page, `nil` is
  returned instead.
  """

  alias AeMdw.Db.Mutation
  alias AeMdw.Db.RocksDb
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State

  @type table() :: atom()
  @type record() :: tuple()
  @type key() :: term()
  @type direction() :: :forward | :backward
  @type cursor() :: key() | nil
  @type limit() :: pos_integer()
  @type transaction() :: RocksDb.transaction()

  @spec count_keys(table()) :: non_neg_integer()
  def count_keys(table) do
    RocksDbCF.count(table)
  end

  @spec all_keys(table()) :: [key()]
  def all_keys(table) do
    RocksDbCF.all_keys(table)
  end

  @spec dirty_delete(table(), key()) :: :ok
  def dirty_delete(tab, key) do
    :ok = RocksDbCF.dirty_delete(tab, key)
  end

  @spec dirty_fetch(transaction(), table(), key()) :: {:ok, record()} | :not_found
  def dirty_fetch(txn, table, key) do
    RocksDbCF.dirty_fetch(txn, table, key)
  end

  @spec dirty_write(table(), record()) :: :ok
  def dirty_write(table, record) do
    RocksDbCF.dirty_put(table, record)
  end

  @spec last_key(table(), term()) :: term()
  def last_key(tab, default) do
    case last_key(tab) do
      {:ok, last_key} -> last_key
      :none -> default
    end
  end

  @spec last_key(table()) :: {:ok, key()} | :none
  def last_key(tab) do
    case RocksDbCF.last_key(tab) do
      {:ok, last_key} -> {:ok, last_key}
      :not_found -> :none
    end
  end

  @spec first_key(table(), term()) :: term()
  def first_key(tab, default) do
    case first_key(tab) do
      {:ok, first_key} -> first_key
      :none -> default
    end
  end

  @spec first_key(table()) :: {:ok, key()} | :none
  def first_key(tab) do
    case RocksDbCF.first_key(tab) do
      {:ok, first_key} -> {:ok, first_key}
      :not_found -> :none
    end
  end

  @spec prev_key(table(), key()) :: {:ok, key()} | :none
  def prev_key(tab, key) do
    case RocksDbCF.prev_key(tab, key) do
      {:ok, prev_key} -> {:ok, prev_key}
      :not_found -> :none
    end
  end

  @spec next_key(table(), key()) :: {:ok, key()} | :none
  def next_key(tab, key) do
    case RocksDbCF.next_key(tab, key) do
      {:ok, next_key} -> {:ok, next_key}
      :not_found -> :none
    end
  end

  @spec dirty_next(transaction(), table(), key()) :: {:ok, key()} | :none
  def dirty_next(txn, tab, key) do
    case RocksDbCF.dirty_next(txn, tab, key) do
      {:ok, next_key} -> {:ok, next_key}
      :not_found -> :none
    end
  end

  @spec next_key(table(), direction(), key()) :: {:ok, key()} | :none
  def next_key(tab, :forward, nil), do: first_key(tab)
  def next_key(tab, :forward, cursor), do: next_key(tab, cursor)

  def next_key(tab, :backward, nil), do: last_key(tab)
  def next_key(tab, :backward, cursor), do: prev_key(tab, cursor)

  @spec fetch(table(), key()) :: {:ok, record()} | :not_found
  def fetch(tab, key) do
    RocksDbCF.fetch(tab, key)
  end

  @spec fetch!(table(), key()) :: record()
  def fetch!(tab, key) do
    {:ok, record} = fetch(tab, key)

    record
  end

  @spec exists?(table(), key()) :: boolean()
  def exists?(tab, key) do
    RocksDbCF.exists?(tab, key)
  end

  @spec read(table(), key()) :: [record()]
  def read(tab, key) do
    case RocksDbCF.fetch(tab, key) do
      {:ok, record} -> [record]
      :not_found -> []
    end
  end

  @spec write(transaction(), table(), record()) :: :ok
  def write(txn, tab, record) do
    RocksDbCF.put(txn, tab, record)
  end

  @spec delete(transaction(), table(), key()) :: :ok
  def delete(txn, table, key) do
    :ok = RocksDbCF.delete(txn, table, key)
  end

  @doc """
  Creates a transaction and commits the changes of a mutation list.

  Left for backwards compat to deal with invalidations.
  """
  @spec commit([Mutation.t()]) :: :ok
  def commit(mutations) do
    State.new()
    |> State.commit(mutations)

    :ok
  end
end
