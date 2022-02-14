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

  @type index :: term()
  @type table :: atom()
  @type record :: tuple()

  @block_tab :rdbcf_block
  @tx_tab :rdbcf_tx

  @tables_with_unused_value [Model.Field, Model.Time, Model.Type]

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

  @spec put(table(), record()) :: :ok
  def put(table, record) do
    key = encode_record_index(record)
    value = encode_record_value(table, record)

    cache_insert(record)
    :ok = RocksDb.put(table, key, value)
  end

  @spec delete(table(), index()) :: :ok | {:error, any}
  def delete(table, index) do
    key = :sext.encode(index)

    RocksDb.delete(table, key)
  end

  @spec exists?(table(), index()) :: boolean()
  def exists?(table, index) do
    key = :sext.encode(index)

    case RocksDb.get(table, key) do
      {:ok, _value} -> true
      :not_found -> false
    end
  end

  @spec first_key(table()) :: {:ok, index()} | :not_found
  def first_key(table) do
    {:ok, it} = RocksDb.iterator(table)

    key_res = do_iterator_move(it, :first)

    :rocksdb.iterator_close(it)

    key_res
  end

  @spec last_key(table(), boolean()) :: {:ok, index()} | :not_found
  def last_key(table, cached? \\ true)

  def last_key(Model.Block, true) do
    case :ets.last(@block_tab) do
      :"$end_of_table" -> last_key(Model.Block, false)
      key -> {:ok, key}
    end
  end

  def last_key(Model.Tx, true) do
    case :ets.last(@tx_tab) do
      :"$end_of_table" -> last_key(Model.Tx, false)
      key -> {:ok, key}
    end
  end

  def last_key(table, false) do
    {:ok, it} = RocksDb.iterator(table)

    key_res = do_iterator_move(it, :last)

    :rocksdb.iterator_close(it)

    key_res
  end

  @spec next_key(table(), index()) :: {:ok, index()} | :not_found
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

    :rocksdb.iterator_close(it)

    key_res
  end

  @spec prev_key(table(), index()) :: {:ok, index()} | :not_found
  def prev_key(table, seek_index) do
    {:ok, it} = RocksDb.iterator(table)
    seek_key = :sext.encode(seek_index)

    key_res =
      case do_iterator_move(it, seek_key) do
        {:ok, index} ->
          if index != seek_index do
            {:ok, index}
          else
            do_iterator_move(it, :prev)
          end

        :not_found ->
          :not_found
      end

    :rocksdb.iterator_close(it)

    key_res
  end

  @spec search_prev_key(table(), index(), index(), {pos_integer(), any()}) ::
          {:ok, index()} | :not_found
  def search_prev_key(
        table,
        lower_bound_index,
        upper_bound_index,
        {field_pos, _field_value} = value_to_match
      )
      when field_pos > 1 do
    upper_bound_key = :sext.encode(upper_bound_index)
    lower_bound_key = :sext.encode(lower_bound_index)
    {:ok, it} = RocksDb.iterator(table, iterate_lower_bound: lower_bound_key)

    key_res = do_search_prev_key(it, upper_bound_key, value_to_match)

    :rocksdb.iterator_close(it)

    key_res
  end

  @spec dirty_fetch(table(), index()) :: {:ok, record()} | :not_found
  def dirty_fetch(table, index) do
    key = :sext.encode(index)

    case RocksDb.dirty_get(table, key) do
      {:ok, value} ->
        record_type = Model.record(table)

        record =
          table
          |> decode_value(value)
          |> Tuple.insert_at(0, index)
          |> Tuple.insert_at(0, record_type)

        {:ok, record}

      :not_found ->
        :not_found
    end
  end

  @spec dirty_fetch!(table(), index()) :: record()
  def dirty_fetch!(table, index) do
    {:ok, record} = dirty_fetch(table, index)

    record
  end

  @spec fetch(table(), index()) :: {:ok, record()} | :not_found
  def fetch(table, index) do
    key = :sext.encode(index)

    case RocksDb.get(table, key) do
      {:ok, value} ->
        record_type = Model.record(table)

        record =
          table
          |> decode_value(value)
          |> Tuple.insert_at(0, index)
          |> Tuple.insert_at(0, record_type)

        {:ok, record}

      :not_found ->
        :not_found
    end
  end

  @spec fetch!(table(), index()) :: record()
  def fetch!(table, index) do
    {:ok, record} = dirty_fetch(table, index)

    record
  end

  #
  # Private functions
  #
  defp encode_record_index(record), do: record |> elem(1) |> :sext.encode()

  defp encode_record_value(table, _record) when table in @tables_with_unused_value, do: ""

  defp encode_record_value(_table, record) do
    record
    |> Tuple.delete_at(0)
    |> Tuple.delete_at(0)
    |> :sext.encode()
  end

  defp decode_value(table, _value) when table in @tables_with_unused_value, do: {}
  defp decode_value(_table, value), do: :sext.decode(value)

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

  defp do_search_prev_key(it, key, {field_pos, field_value} = value_to_match) do
    case :rocksdb.iterator_move(it, {:prev, key}) do
      {:ok, prev_key, prev_value} ->
        prev_field_value = prev_value |> :sext.decode() |> elem(field_pos - 1)

        if prev_field_value == field_value do
          prev_key
        else
          do_search_prev_key(it, prev_key, value_to_match)
        end

      {:error, :invalid_iterator} ->
        :not_found
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
