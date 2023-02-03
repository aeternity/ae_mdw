defmodule AeMdw.Db.RocksDbCF do
  @moduledoc """
  RocksDb column family operations using AeMdw.Db.Model records and indexes.

  The key-value is saved encoded with :sext to acomplish the pre-requisite of saving strings (binary type) while
  keeping the ordering of erlang terms (same as mnesia_rocksdb). This way the key-value works like a sorted set
  and naturally the read operations decode both key and value to original erlang term.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDb

  require Model

  @type key :: term()
  @type table :: atom()
  @type record :: tuple()
  @typep transaction :: RocksDb.transaction()

  @spec all_keys(table()) :: [key()]
  def all_keys(table) do
    {:ok, it} = RocksDb.iterator(table)

    key_res = do_iterator_move(it, :first)

    all_keys_list = do_all_keys([], it, key_res)

    RocksDb.iterator_close(it)

    all_keys_list
  end

  @spec count(table()) :: non_neg_integer()
  def count(table) do
    {:ok, it} = RocksDb.iterator(table)

    iterator_count(it)
  end

  @spec count_range(table(), key(), key()) :: non_neg_integer()
  def count_range(table, min_key, max_key) do
    {:ok, it} = RocksDb.iterator(table)

    seek_key = :sext.encode(min_key)

    count =
      it
      |> do_iterator_move({:seek, seek_key})
      |> Stream.unfold(fn
        {:ok, key} when key <= max_key -> {key, do_iterator_move(it, :next)}
        {:ok, _key} -> nil
        :not_found -> nil
      end)
      |> Enum.count()

    RocksDb.iterator_close(it)

    count
  end

  @spec dirty_count(transaction(), table()) :: non_neg_integer()
  def dirty_count(txn, table) do
    {:ok, it} = RocksDb.dirty_iterator(txn, table)

    iterator_count(it)
  end

  @spec put(transaction(), table(), record()) :: :ok
  def put(txn, table, record) do
    key = encode_record_index(record)
    value = encode_record_value(record)

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

  @spec exists?(transaction(), table(), key()) :: boolean()
  def exists?(txn, table, index) do
    key = :sext.encode(index)

    case RocksDb.dirty_get(txn, table, key) do
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

    iterator_next_key(it, seek_index)
  end

  @spec dirty_next(transaction(), table(), key()) :: {:ok, key()} | :not_found
  def dirty_next(txn, table, seek_index) do
    {:ok, it} = RocksDb.dirty_iterator(txn, table)

    iterator_next_key(it, seek_index)
  end

  @spec dirty_prev(transaction(), table(), key()) :: {:ok, key()} | :not_found
  def dirty_prev(txn, table, seek_index) do
    {:ok, it} = RocksDb.dirty_iterator(txn, table)

    iterator_prev_key(it, seek_index)
  end

  @spec prev_key(table(), key()) :: {:ok, key()} | :not_found
  def prev_key(table, seek_index) do
    {:ok, it} = RocksDb.iterator(table)

    iterator_prev_key(it, seek_index)
  end

  @spec dirty_put(table(), record()) :: :ok
  def dirty_put(table, record) do
    key = encode_record_index(record)
    value = encode_record_value(record)

    :ok = RocksDb.dirty_put(table, key, value)
  end

  @spec dirty_delete(table(), key()) :: :ok
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
  defp iterator_next_key(it, seek_index) do
    seek_key = :sext.encode(seek_index)

    key_res =
      case do_iterator_move(it, {:seek_for_prev, seek_key}) do
        {:ok, _index} -> do_iterator_move(it, :next)
        :not_found -> do_iterator_move(it, :first)
      end

    RocksDb.iterator_close(it)

    key_res
  end

  defp iterator_prev_key(it, seek_index) do
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

  defp do_all_keys(keys, _it, :not_found), do: Enum.reverse(keys)

  defp do_all_keys(keys, it, {:ok, key}) do
    do_all_keys([key | keys], it, do_iterator_move(it, :next))
  end

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

  defp iterator_count(it) do
    key_res = do_iterator_move(it, :first)

    count = do_count(0, it, key_res)

    RocksDb.iterator_close(it)

    count
  end
end
