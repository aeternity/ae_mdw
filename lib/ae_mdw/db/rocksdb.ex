defmodule AeMdw.Db.RocksDb do
  @moduledoc """
  RocksDb wrapper around the :rocksdb library which interacts with RocksDB using NIFs and erlang references.

  The tables are opened in a single database, for optimistic transactions, so RocksDB raises an exception on
  conflict which is helpful to identify unwanted parallelism in the future when it doesn't respect dependency.

  There are 4 types of references:
  - database
  - the table references, one for each column family
  - transaction
  - iterator

  The transaction and iterator are returned by public function. The database and table references are internal use only.
  A column family iterator is created and released on demand (e.g. for next and prev after multiple iterations).

  An specific transaction reference is required for every commit. In order to write directly, a dirty_put can be used.
  """
  alias AeMdw.Log
  alias AeMdw.Db.Model

  @opaque iterator :: reference() | binary()
  @opaque transaction :: reference() | binary()
  @typep table :: atom()

  # arround 50 column families * 10
  @max_open_files 500
  # see https://github.com/facebook/rocksdb/wiki/Space-Tuning
  @block_size 4 * 1024
  @block_cache_size 32 * 1024 * 1024
  @write_buffer_size 32 * 1024 * 1024

  @db_options [
    create_if_missing: true,
    create_missing_column_families: true,
    max_open_files: @max_open_files,
    merge_operator: :erlang_merge_operator
  ]
  @cf_options [
    # see https://github.com/facebook/rocksdb/wiki/Space-Tuning
    compression: :lz4,
    bottommost_compression: :zstd,
    write_buffer_size: @write_buffer_size,
    block_based_table_options: [
      block_size: @block_size,
      block_cache_size: @block_cache_size,
      cache_index_and_filter_blocks: true,
      format_version: 5
    ],
    merge_operator: :erlang_merge_operator
  ]

  @doc """
  Opens an optimistic transaction database with multiple column families in order to allow transactions
  across multiple tables.
  """
  @spec open() :: :ok
  def open() do
    with :ok <- create_dir_if_missing(),
         {:ok, db_ref, cf_ref_list} <- open_db() do
      # keep db handle
      :persistent_term.put({__MODULE__, :db_ref}, db_ref)

      # map each cf handle to its cf model
      all_cf_names()
      |> Enum.zip(cf_ref_list)
      |> Enum.each(fn {cf_name, cf_ref} ->
        :persistent_term.put({__MODULE__, cf_name}, {db_ref, cf_ref})
      end)
    else
      {:error, reason} ->
        Log.error("Failed to open database! path=#{data_dir()}, reason=#{inspect(reason)}")
        :error
    end
  end

  @doc """
  Puts changes into a specific optimistic transaction.
  """
  @spec put(transaction(), table(), binary(), binary()) :: :ok
  def put(t_ref, table, key, value) do
    {_db_ref, cf_ref} = cf_refs(table)

    :rocksdb.transaction_put(t_ref, cf_ref, key, value)
  end

  @doc """
  Read directly from DB (only commited data).
  """
  @spec get(table(), binary()) ::
          {:ok, binary()} | :not_found | {:error, {:corruption, charlist()}} | {:error, any()}
  def get(table, key) do
    {db_ref, cf_ref} = cf_refs(table)
    :rocksdb.get(db_ref, cf_ref, key, [])
  end

  @doc """
  Starts a new empty transaction with fsync option.
  """
  @spec transaction_new() :: {:ok, transaction()}
  def transaction_new do
    {:ok, _t_ref} = :rocksdb.transaction(db_ref(), sync: true)
  end

  @doc """
  Commits transaction changes.
  """
  @spec transaction_commit(transaction()) :: :ok | {:error, term()}
  defdelegate transaction_commit(tref), to: :rocksdb

  @doc """
  Iterator for a column family.
  """
  @spec iterator(table(), Keyword.t()) :: {:ok, iterator()} | {:error, any()}
  def iterator(table, read_options \\ []) do
    {db_ref, cf_ref} = cf_refs(table)

    :rocksdb.iterator(db_ref, cf_ref, read_options)
  end

  @doc """
  Release iterator.
  """
  @spec iterator_close(iterator()) :: :ok
  defdelegate iterator_close(it), to: :rocksdb

  @doc """
  Delete a key without a transaction.
  """
  @spec dirty_delete(table(), binary()) :: :ok | {:error, any()}
  def dirty_delete(table, key) do
    {db_ref, cf_ref} = cf_refs(table)

    :rocksdb.delete(db_ref, cf_ref, key, [])
  end

  @doc """
  Write a key-value directly without a transaction.
  """
  @spec dirty_put(table(), binary(), binary()) :: :ok
  def dirty_put(table, key, value) do
    {db_ref, cf_ref} = cf_refs(table)

    :ok = :rocksdb.put(db_ref, cf_ref, key, value, [])
  end

  @doc """
  Read through transaction (not commited) and then DB.
  """
  @spec dirty_get(transaction(), table(), binary()) ::
          {:ok, binary()} | :not_found | {:error, {:corruption, charlist()}} | {:error, any()}
  def dirty_get(t_ref, table, key) do
    {db_ref, cf_ref} = cf_refs(table)

    case :rocksdb.transaction_get(t_ref, cf_ref, key, []) do
      {:ok, value} -> {:ok, value}
      :not_found -> :rocksdb.get(db_ref, cf_ref, key, [])
      error -> error
    end
  end

  @doc """
  Delete a key-value from a column family.
  """
  @spec delete(transaction(), table(), binary()) :: :ok | {:error, any()}
  def delete(t_ref, table, key) do
    {db_ref, cf_ref} = cf_refs(table)

    case :rocksdb.transaction_get(t_ref, cf_ref, key, []) do
      {:ok, _value} ->
        :ok = :rocksdb.transaction_delete(t_ref, cf_ref, key)

      :not_found ->
        :rocksdb.delete(db_ref, cf_ref, key, [])

      error ->
        error
    end
  end

  @doc """
  Closes the database (with all column familes).
  """
  @spec close() :: :ok
  def close() do
    db_ref()
    |> :rocksdb.close()
  end

  #
  # Private functions
  #
  defp create_dir_if_missing() do
    if File.exists?(data_dir()) do
      :ok
    else
      File.mkdir(data_dir())
    end
  end

  defp open_db() do
    cf_descriptors =
      all_cf_names()
      |> Enum.map(fn cf_name ->
        {Atom.to_charlist(cf_name), @cf_options}
      end)

    data_dir()
    |> String.to_charlist()
    |> :rocksdb.open_optimistic_transaction_db(@db_options, cf_descriptors)
  end

  defp all_cf_names() do
    [:default | Model.column_families()]
  end

  defp db_ref(), do: :persistent_term.get({__MODULE__, :db_ref})
  defp cf_refs(cf_name), do: :persistent_term.get({__MODULE__, cf_name})

  defp data_dir(), do: Application.fetch_env!(:ae_mdw, __MODULE__)[:data_dir]
end
