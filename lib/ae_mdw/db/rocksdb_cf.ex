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

  @spec put(table(), record()) :: :ok
  def put(table, record) do
    key = encode_record_index(record)
    value = encode_record_value(record)

    :ok = RocksDb.put(table, key, value)
  end

  @spec delete(table(), key()) :: :ok | {:error, any}
  def delete(table, index) do
    key = :sext.encode(index)

    :ok = RocksDb.delete(table, key)
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
      case do_iterator_move(it, seek_key) do
        {:ok, index} ->
          if index != seek_index do
            {:ok, index}
          else
            do_iterator_move(it, :next)
          end

        :not_found ->
          :not_found
      end

    RocksDb.iterator_close(it)

    key_res
  end

  @spec prev_key(table(), key()) :: {:ok, key()} | :not_found
  def prev_key(table, seek_index) do
    {:ok, it} = RocksDb.iterator(table)
    seek_key = :sext.encode(seek_index)

    key_res =
      case do_iterator_move(it, seek_key) do
        {:ok, _index} -> do_iterator_move(it, :prev)
        :not_found -> :not_found
      end

    RocksDb.iterator_close(it)

    key_res
  end

  @spec dirty_fetch(table(), key()) :: {:ok, record()} | :not_found
  def dirty_fetch(table, index) do
    key = :sext.encode(index)

    case RocksDb.dirty_get(table, key) do
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

  @spec dirty_fetch!(table(), key()) :: record()
  def dirty_fetch!(table, index) do
    {:ok, record} = dirty_fetch(table, index)

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
    {:ok, record} = dirty_fetch(table, index)

    record
  end

  #
  # Private functions
  #
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
end
