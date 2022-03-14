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

  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.TxnMutation
  alias AeMdw.Db.RocksDb
  alias AeMdw.Db.RocksDbCF

  @type table() :: atom()
  @type record() :: tuple()
  @type key() :: term()
  @type direction() :: :forward | :backward
  @type cursor() :: key() | nil
  @type limit() :: pos_integer()
  @type transaction() :: RocksDb.transaction()

  @end_token :"$end_of_table"

  defmacro use_rocksdb?(tab) do
    quote do
      unquote(tab) == Model.Block or
        unquote(tab) == Model.Tx or
        unquote(tab) == Model.Aex9Balance or
        unquote(tab) == Model.ActiveOracleExpiration or
        unquote(tab) == Model.InactiveOracleExpiration or
        unquote(tab) == Model.ActiveOracle or
        unquote(tab) == Model.InactiveOracle or
        unquote(tab) == Model.AsyncTasks or
        unquote(tab) == Model.Migrations or
        unquote(tab) == Model.DeltaStat or
        unquote(tab) == Model.TotalStat
    end
  end

  @spec count_keys(table()) :: non_neg_integer()
  def count_keys(table) when use_rocksdb?(table) do
    RocksDbCF.count(table)
  end

  def count_keys(table) do
    table |> :mnesia.dirty_all_keys() |> length()
  end

  @spec dirty_all_keys(table()) :: [key()]
  def dirty_all_keys(table) do
    :mnesia.dirty_all_keys(table)
  end

  @spec dirty_delete(table(), key()) :: :ok
  def dirty_delete(tab, key) when use_rocksdb?(tab) do
    :ok = RocksDbCF.dirty_delete(tab, key)
  end

  def dirty_delete(tab, key), do: :mnesia.dirty_delete(tab, key)

  @spec dirty_fetch(transaction(), table(), record()) :: {:ok, record()} | :not_found
  def dirty_fetch(txn, table, record) when use_rocksdb?(table) do
    RocksDbCF.dirty_fetch(txn, table, record)
  end

  @spec dirty_read(table(), key()) :: [record()]
  def dirty_read(tab, key), do: :mnesia.dirty_read(tab, key)

  @spec dirty_first(table()) :: key()
  def dirty_first(tab), do: :mnesia.dirty_first(tab)

  @spec dirty_last(table()) :: key()
  def dirty_last(tab), do: :mnesia.dirty_last(tab)

  @spec dirty_next(table(), key()) :: key()
  def dirty_next(tab, key), do: :mnesia.dirty_next(tab, key)

  @spec dirty_prev(table(), key()) :: key()
  def dirty_prev(tab, key), do: :mnesia.dirty_prev(tab, key)

  @spec dirty_write(table(), record()) :: :ok
  def dirty_write(table, record) when use_rocksdb?(table) do
    RocksDbCF.dirty_put(table, record)
  end

  def dirty_write(table, record), do: :mnesia.dirty_write(table, record)

  @spec dirty_select(table(), list()) :: [term()]
  def dirty_select(table, fun), do: :mnesia.dirty_select(table, fun)

  @spec all_keys(table()) :: [key()]
  def all_keys(table) when use_rocksdb?(table) do
    RocksDbCF.all_keys(table)
  end

  def all_keys(table) do
    :mnesia.all_keys(table)
  end

  @doc """
  Previous key reading through the transaction.
  """
  @spec dirty_prev_key(table(), key()) :: {:ok, key()} | :none
  def dirty_prev_key(tab, key) do
    case :mnesia.prev(tab, key) do
      @end_token -> :none
      prev_key -> {:ok, prev_key}
    end
  end

  @spec last_key(table(), term()) :: term()
  def last_key(tab, default) do
    case last_key(tab) do
      {:ok, last_key} -> last_key
      :none -> default
    end
  end

  @spec last_key(table()) :: {:ok, key()} | :none
  def last_key(tab) when use_rocksdb?(tab) do
    case RocksDbCF.last_key(tab) do
      {:ok, last_key} -> {:ok, last_key}
      :not_found -> :none
    end
  end

  def last_key(tab) do
    case :mnesia.dirty_last(tab) do
      @end_token -> :none
      last_key -> {:ok, last_key}
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
  def first_key(tab) when use_rocksdb?(tab) do
    case RocksDbCF.first_key(tab) do
      {:ok, first_key} -> {:ok, first_key}
      :not_found -> :none
    end
  end

  def first_key(tab) do
    case :mnesia.dirty_first(tab) do
      @end_token -> :none
      last_key -> {:ok, last_key}
    end
  end

  @spec prev_key(table(), key()) :: {:ok, key()} | :none
  def prev_key(tab, key) when use_rocksdb?(tab) do
    case RocksDbCF.prev_key(tab, key) do
      {:ok, prev_key} -> {:ok, prev_key}
      :not_found -> :none
    end
  end

  def prev_key(tab, key) do
    case :mnesia.dirty_prev(tab, key) do
      @end_token -> :none
      record -> {:ok, record}
    end
  end

  @spec next_key(table(), key()) :: {:ok, key()} | :none
  def next_key(tab, key) when use_rocksdb?(tab) do
    case RocksDbCF.next_key(tab, key) do
      {:ok, next_key} -> {:ok, next_key}
      :not_found -> :none
    end
  end

  def next_key(tab, key) do
    case :mnesia.dirty_next(tab, key) do
      @end_token -> :none
      record -> {:ok, record}
    end
  end

  @spec next_key(table(), direction(), key()) :: {:ok, key()} | :none
  def next_key(tab, :forward, nil), do: first_key(tab)
  def next_key(tab, :forward, cursor), do: next_key(tab, cursor)

  def next_key(tab, :backward, nil), do: last_key(tab)
  def next_key(tab, :backward, cursor), do: prev_key(tab, cursor)

  @spec fetch(table(), key()) :: {:ok, record()} | :not_found
  def fetch(tab, key) when use_rocksdb?(tab) do
    RocksDbCF.fetch(tab, key)
  end

  def fetch(tab, key) do
    case :mnesia.dirty_read(tab, key) do
      [record] -> {:ok, record}
      [] -> :not_found
    end
  end

  @spec fetch!(table(), key()) :: record()
  def fetch!(tab, key) do
    {:ok, record} = fetch(tab, key)

    record
  end

  @spec exists?(table(), key()) :: boolean()
  def exists?(tab, key) do
    match?({:ok, _record}, fetch(tab, key))
  end

  @spec read(table(), key()) :: [record()]
  def read(tab, key) when use_rocksdb?(tab) do
    case RocksDbCF.fetch(tab, key) do
      {:ok, record} -> [record]
      :not_found -> []
    end
  end

  def read(table, key) do
    :mnesia.read(table, key)
  end

  @spec read(table(), key(), :read | :write) :: [record()]
  def read(table, key, lock) do
    :mnesia.read(table, key, lock)
  end

  @spec write(transaction(), table(), record()) :: :ok
  def write(txn, tab, record) when use_rocksdb?(tab) do
    RocksDbCF.put(txn, tab, record)
  end

  @spec write(table(), record()) :: :ok
  def write(table, record) do
    :mnesia.write(table, record, :write)
  end

  @spec delete(transaction(), table(), key()) :: :ok
  def delete(txn, table, key) when use_rocksdb?(table) do
    :ok = RocksDbCF.delete(txn, table, key)
  end

  @spec delete(table(), key()) :: :ok
  def delete(table, key) do
    :mnesia.delete(table, key, :write)
  end

  @doc """
  Creates a transaction and commits the changes of a mutation list.
  """
  @spec commit([TxnMutation.t()]) :: :ok
  def commit(txn_mutations) do
    {:ok, txn} = RocksDb.transaction_new()

    txn_mutations
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.each(&TxnMutation.execute(&1, txn))

    :ok = RocksDb.transaction_commit(txn)
  end

  @spec transaction([Mutation.t()]) :: :ok
  def transaction(mutations) do
    mutations =
      mutations
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    {:atomic, :ok} =
      :mnesia.sync_transaction(fn ->
        Enum.each(mutations, &Mutation.mutate/1)
      end)

    :ok
  end
end
