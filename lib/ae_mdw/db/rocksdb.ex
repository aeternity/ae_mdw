defmodule AeMdw.Db.RocksDb do
  @moduledoc """
  RocksDb wrapper around the :rocksdb library which interacts with RocksDB using NIFs and erlang references.

  There are 4 types of references:
  - database
  - the table references, one for each column family
  - transaction
  - iterator

  Only the iterator is return by public function (the others are internal use only).
  A column family iterator is created and released on demand (e.g. for next and prev after multiple iterations).

  A transaction is automatically started by the first put and finishes with a commit.
  On the next put a new transaction begins. In order to write directly, a dirty_put can be used.
  """
  alias AeMdw.Log
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation

  @opaque iterator :: reference() | binary()
  # when transactions are explicit use:
  # @opaque transaction :: reference() | binary()
  @typep table :: atom()

  # arround 50 column families * 10
  @max_open_files 500
  # default from https://github.com/facebook/rocksdb/wiki/Space-Tuning
  @block_size 4 * 1024
  @block_cache_size 32 * 1024 * 1024
  @write_buffer_size 32 * 1024 * 1024

  @db_options [
    create_if_missing: true,
    create_missing_column_families: true,
    max_background_compactions: 4,
    max_background_flushes: 2,
    use_fsync: true,
    bytes_per_sync: 1_048_576,
    max_open_files: @max_open_files,
    merge_operator: :erlang_merge_operator
  ]
  @cf_options [
    # Mdw db is only 4% of total used storage
    # (with cpu-optimized machines we can get probably faster writes by enabling it though)
    compression: :none,
    bottommost_compression: :none,
    write_buffer_size: @write_buffer_size,
    block_based_table_options: [
      block_size: @block_size,
      block_cache_size: @block_cache_size,
      cache_index_and_filter_blocks: true,
      format_version: 5
    ],
    level_compaction_dynamic_level_bytes: true,
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
  Puts changes into an optimistic transaction.

  RocksDB raises an exception on conflict which is helpful to identify unwanted parallelism in the future when
  it doesn't respect dependency.
  """
  @spec put(table(), binary(), binary()) :: :ok | :error
  def put(table, key, value) do
    with {_db_ref, cf_ref} <- cf_refs(table),
         {:ok, t_ref} <- get_transaction() do
      :ok = :rocksdb.transaction_put(t_ref, cf_ref, key, value)
    else
      error ->
        Log.error("put failed! reason=#{error}")
        :error
    end
  end

  @doc """
  Commits changes made with put/3
  """
  @spec commit() :: :ok | :error
  def commit() do
    case get_existing_transaction() do
      {:ok, t_ref} ->
        :ok = :rocksdb.transaction_commit(t_ref)
        :ok = :persistent_term.put({__MODULE__, :transaction}, nil)

      :not_found ->
        :error
    end
  end

  @doc """
  Creates a transaction and commits a list of mutations.
  """
  @spec commit([Mutation.t()]) :: :ok | :error
  def commit(mutation_list) do
    {:ok, t_ref} = new_transaction()

    Enum.each(mutation_list, &Mutation.mutate/1)

    :ok = :rocksdb.transaction_commit(t_ref)
    :ok = :persistent_term.put({__MODULE__, :transaction}, nil)
  end

  @doc """
  Read through operation on transaction (not commited) and DB.
  """
  @spec dirty_get(table(), binary()) ::
          {:ok, binary()} | :not_found | {:error, {:corruption, charlist()}} | {:error, any()}
  def dirty_get(table, key) do
    {db_ref, cf_ref} = cf_refs(table)

    with {:ok, t_ref} <- get_existing_transaction(),
         {:ok, value} <- :rocksdb.transaction_get(t_ref, cf_ref, key, []) do
      {:ok, value}
    else
      _not_found ->
        :rocksdb.get(db_ref, cf_ref, key, [])
    end
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
  Iterator for a column family.
  """
  @spec iterator(table(), Keyword.t()) :: {:ok, iterator()} | {:error, any()}
  def iterator(table, read_options \\ []) do
    {db_ref, cf_ref} = cf_refs(table)

    :rocksdb.iterator(db_ref, cf_ref, read_options)
  end

  @doc """
  Delete a key-value from a column family.
  """
  @spec delete(table(), binary()) :: :ok | {:error, any()}
  def delete(table, key) do
    {db_ref, cf_ref} = cf_refs(table)

    with {:ok, t_ref} <- get_existing_transaction(),
         {:ok, _value} <- :rocksdb.transaction_get(t_ref, cf_ref, key, []) do
      :ok = :rocksdb.transaction_delete(t_ref, cf_ref, key)
    else
      :not_found ->
        :rocksdb.delete(db_ref, cf_ref, key, [])
    end
  end

  @doc """
  Write directly without transaction for single writes.
  """
  @spec dirty_put(table(), binary(), binary()) :: :ok
  def dirty_put(table, key, value) do
    {db_ref, cf_ref} = cf_refs(table)

    :ok = :rocksdb.put(db_ref, cf_ref, key, value, [])
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

  defp get_existing_transaction() do
    case :persistent_term.get({__MODULE__, :transaction}, nil) do
      # :rocksdb works with :not_found with its functions but we can change we can change use :none as Mnesia module
      nil -> :not_found
      t_ref -> {:ok, t_ref}
    end
  end

  defp get_transaction() do
    case :persistent_term.get({__MODULE__, :transaction}, nil) do
      nil -> new_transaction()
      t_ref -> {:ok, t_ref}
    end
  end

  defp new_transaction() do
    case :rocksdb.transaction(db_ref(), sync: true) do
      {:ok, t_ref} ->
        :persistent_term.put({__MODULE__, :transaction}, t_ref)
        {:ok, t_ref}

      error ->
        error
    end
  end

  defp db_ref(), do: :persistent_term.get({__MODULE__, :db_ref})
  defp cf_refs(cf_name), do: :persistent_term.get({__MODULE__, cf_name})

  defp data_dir(), do: Application.fetch_env!(:ae_mdw, __MODULE__)[:data_dir]
end
