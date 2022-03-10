defmodule AeMdw.Db.RocksDbCF do
  @moduledoc """
  RocksDb column family operations using AeMdw.Db.Model records and indexes.

  The key-value is saved encoded with :sext to acomplish the pre-requisite of saving strings (binary type) while
  keeping the ordering of erlang terms (same as mnesia_rocksdb). This way the key-value works like a sorted set
  and naturally the read operations decode both key and value to original erlang term.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDb
  alias AeMdw.Blocks

  require Model

  @type key :: term()
  @type table :: atom()
  @type record :: tuple()
  @typep transaction :: RocksDb.transaction()

  @block_tab :rdbcf_block
  @tx_tab :rdbcf_tx

  @spec init_tables() :: :ok
  def init_tables() do
    :ets.new(@block_tab, [:named_table, :public, :ordered_set])
    :ets.new(@tx_tab, [:named_table, :public, :ordered_set])
  end

  @spec read_block(Blocks.block_index_txi_pos()) :: {:ok, Model.block()} | :not_found
  def read_block(block_index) do
    read_through(@block_tab, Model.Block, block_index)
  end

  @spec read_tx(AeMdw.Txs.txi()) :: {:ok, Model.tx()} | :not_found
  def read_tx(txi) do
    read_through(@tx_tab, Model.Tx, txi)
  end

  @spec count(table()) :: non_neg_integer()
  def count(table) do
    {:ok, it} = RocksDb.iterator(table)

    key_res = do_iterator_move(it, :first)

    count = do_count(0, it, key_res)

    RocksDb.iterator_close(it)

    count
  end

  @spec put(transaction(), table(), record()) :: :ok
  def put(txn, table, record) do
    key = encode_record_index(record)
    value = encode_record_value(record)

    cache_insert(record)
    :ok = RocksDb.put(txn, table, key, value)
  end

  @spec delete(transaction(), table(), key()) :: :ok
  def delete(txn, table, index) do
    key = :sext.encode(index)

    :ok = RocksDb.delete(txn, table, key)
  end

  @spec exists?(table(), key()) :: boolean()
  def exists?(table, index) do
    key = :sext.encode(index)

    case RocksDb.get(table, key) do
      {:ok, _value} -> true
      :not_found -> false
    end
  end

  @spec first_key(table()) :: {:ok, key()} | :not_found
  def first_key(table) do
    {:ok, it} = RocksDb.iterator(table)

    key_res = do_iterator_move(it, :first)

    RocksDb.iterator_close(it)

    key_res
  end

  @spec last_key(table()) :: {:ok, key()} | :not_found
  def last_key(table) do
    {:ok, it} = RocksDb.iterator(table)

    key_res = do_iterator_move(it, :last)

    RocksDb.iterator_close(it)

    key_res
  end

  @spec next_key(table(), key()) :: {:ok, key()} | :not_found
  def next_key(table, seek_index) do
    {:ok, it} = RocksDb.iterator(table)
    seek_key = :sext.encode(seek_index)

    key_res =
      case do_iterator_move(it, {:seek_for_prev, seek_key}) do
        {:ok, _index} -> do_iterator_move(it, :next)
        :not_found -> first_key(table)
      end

    RocksDb.iterator_close(it)

    key_res
  end

  @spec prev_key(table(), key()) :: {:ok, key()} | :not_found
  def prev_key(table, seek_index) do
    {:ok, it} = RocksDb.iterator(table)
    seek_key = :sext.encode(seek_index)

    key_res =
      case do_iterator_move(it, {:seek_for_prev, seek_key}) do
        {:ok, index} ->
          if index < seek_index do
            {:ok, index}
          else
            do_iterator_move(it, :prev)
          end

        :not_found ->
          :not_found
      end

    RocksDb.iterator_close(it)

    key_res
  end

  @spec dirty_put(table(), record()) :: :ok | {:error, any}
  def dirty_put(table, record) do
    key = encode_record_index(record)
    value = encode_record_value(record)

    :ok = RocksDb.dirty_put(table, key, value)
  end

  @spec dirty_delete(table(), key()) :: :ok | {:error, any}
  def dirty_delete(table, index) do
    key = :sext.encode(index)

    :ok = RocksDb.dirty_delete(table, key)
  end

  @spec dirty_fetch(transaction(), table(), key()) :: {:ok, record()} | :not_found
  def dirty_fetch(txn, table, index) do
    key = :sext.encode(index)

    case RocksDb.dirty_get(txn, table, key) do
      {:ok, value} ->
        record_type = Model.record(table)

        record =
          value
          |> decode_value()
          |> Tuple.insert_at(0, index)
          |> Tuple.insert_at(0, record_type)

        {:ok, record}

      :not_found ->
        :not_found
    end
  end

  @spec dirty_fetch!(transaction(), table(), key()) :: record()
  def dirty_fetch!(txn, table, index) do
    {:ok, record} = dirty_fetch(txn, table, index)

    record
  end

  @spec fetch(table(), key()) :: {:ok, record()} | :not_found
  def fetch(table, index) do
    key = :sext.encode(index)

    case RocksDb.get(table, key) do
      {:ok, value} ->
        record_type = Model.record(table)

        record =
          value
          |> decode_value()
          |> Tuple.insert_at(0, index)
          |> Tuple.insert_at(0, record_type)

        {:ok, record}

      :not_found ->
        :not_found
    end
  end

  @spec fetch!(table(), key()) :: record()
  def fetch!(table, index) do
    {:ok, record} = fetch(table, index)

    record
  end

  #
  # Private functions
  #

  defp do_count(counter, _it, :not_found), do: counter

  defp do_count(counter, it, _key_res) do
    do_count(counter + 1, it, do_iterator_move(it, :next))
  end

  defp encode_record_index(record), do: record |> elem(1) |> :sext.encode()

  defp encode_record_value({_record_name, _key, nil}), do: ""

  defp encode_record_value(record) do
    record
    |> Tuple.delete_at(0)
    |> Tuple.delete_at(0)
    |> :sext.encode()
  end

  defp decode_value(""), do: {nil}
  defp decode_value(value), do: :sext.decode(value)

  defp do_iterator_move(it, action) do
    case :rocksdb.iterator_move(it, action) do
      {:ok, key, _value} ->
        {:ok, :sext.decode(key)}

      {:error, :invalid_iterator} ->
        :not_found
    end
  end

  defp read_through(cache_table, table, index) do
    case :ets.lookup(cache_table, index) do
      [] ->
        case fetch(table, index) do
          {:ok, record} ->
            cache_insert(record)
            {:ok, record}

          :not_found ->
            :not_found
        end

      [{^index, record}] ->
        {:ok, record}
    end
  end

  defp cache_insert(Model.block(index: block_index) = record) do
    :ets.insert(@block_tab, {block_index, record})
  end

  defp cache_insert(Model.tx(index: txi) = record) do
    :ets.insert(@tx_tab, {txi, record})
  end

  defp cache_insert(_other_record), do: :ok
end
