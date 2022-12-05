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

  alias AeMdw.Db.RocksDb
  alias AeMdw.Db.RocksDbCF

  @type table() :: atom()
  @type record() :: tuple()
  @type key() :: term()
  @type direction() :: :forward | :backward
  @type cursor() :: key() | nil
  @type limit() :: pos_integer()
  @type transaction() :: RocksDb.transaction()

  @spec count(table()) :: non_neg_integer()
  def count(table) do
    RocksDbCF.count(table)
  end

  @spec dirty_count(transaction(), table()) :: non_neg_integer()
  def dirty_count(txn, table) do
    RocksDbCF.dirty_count(txn, table)
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

  @spec dirty_prev(transaction(), table(), key()) :: {:ok, key()} | :none
  def dirty_prev(txn, tab, key) do
    case RocksDbCF.dirty_prev(txn, tab, key) do
      {:ok, prev_key} -> {:ok, prev_key}
      :not_found -> :none
    end
  end

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

  @spec get(table(), key()) :: {:ok, record()} | :not_found
  def get(tab, key) do
    RocksDbCF.fetch(tab, key)
  end

  @spec write(transaction(), table(), record()) :: :ok
  def write(txn, tab, record) do
    RocksDbCF.put(txn, tab, record)
  end

  @spec delete(transaction(), table(), key()) :: :ok
  def delete(txn, table, key) do
    if not RocksDbCF.exists?(txn, table, key) do
      raise "Txn delete on missing key: #{table}, #{inspect(key)}"
    end

    :ok = RocksDbCF.delete(txn, table, key)
  end

  @spec transaction_new() :: transaction()
  def transaction_new do
    {:ok, txn} = RocksDb.transaction_new()
    txn
  end

  @spec transaction_commit(transaction()) :: :ok | {:error, binary()}
  defdelegate transaction_commit(txn), to: RocksDb
end
