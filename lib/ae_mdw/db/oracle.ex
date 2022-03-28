defmodule AeMdw.Db.Oracle do
  @moduledoc """
  Cache through operations for active and inactive oracles.
  """
  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.OracleResponseMutation
  alias AeMdw.Log
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Ex2ms
  require Model
  require Logger

  import AeMdw.Util

  @typep pubkey :: Db.pubkey()
  @typep cache_key :: pubkey() | {pos_integer(), pubkey()}
  @typep transaction :: Database.transaction()

  @spec source(atom(), :expiration) ::
          Model.ActiveOracleExpiration | Model.InactiveOracleExpiration
  def source(Model.ActiveName, :expiration), do: Model.ActiveOracleExpiration
  def source(Model.InactiveName, :expiration), do: Model.InactiveOracleExpiration

  @spec locate(nil | transaction(), pubkey()) ::
          {Model.oracle(), Model.ActiveOracle | Model.InactiveOracle} | nil
  def locate(txn, pubkey) do
    map_ok_nil(cache_through_read(txn, Model.ActiveOracle, pubkey), &{&1, Model.ActiveOracle}) ||
      map_ok_nil(
        cache_through_read(txn, Model.InactiveOracle, pubkey),
        &{&1, Model.InactiveOracle}
      )
  end

  @spec cache_through_read(nil | transaction(), atom(), cache_key()) :: {:ok, tuple()} | nil
  def cache_through_read(nil, table, key) do
    case :ets.lookup(:oracle_sync_cache, {table, key}) do
      [{_, record}] ->
        {:ok, record}

      [] ->
        case Database.fetch(table, key) do
          {:ok, record} -> {:ok, record}
          :not_found -> nil
        end
    end
  end

  def cache_through_read(txn, table, key) do
    case :ets.lookup(:oracle_sync_cache, {table, key}) do
      [{_, record}] ->
        {:ok, record}

      [] ->
        case Database.dirty_fetch(txn, table, key) do
          {:ok, record} -> {:ok, record}
          :not_found -> nil
        end
    end
  end

  @spec cache_through_prev(atom(), cache_key()) :: term()
  def cache_through_prev(table, key),
    do: cache_through_prev(table, key, &(elem(key, 0) == elem(&1, 0)))

  @spec cache_through_prev(atom(), cache_key(), fun()) :: term()
  def cache_through_prev(table, key, key_checker) do
    lookup = fn k, unwrap, eot, chk_fail ->
      case k do
        :"$end_of_table" ->
          eot.()

        prev_key ->
          prev_key = unwrap.(prev_key)
          (key_checker.(prev_key) && {:ok, prev_key}) || chk_fail.()
      end
    end

    nf = fn -> :not_found end

    mns_lookup = fn ->
      case Database.prev_key(table, key) do
        {:ok, prev_key} -> lookup.(prev_key, & &1, nf, nf)
        :none -> :not_found
      end
    end

    lookup.(:ets.prev(:oracle_sync_cache, {table, key}), &elem(&1, 1), mns_lookup, mns_lookup)
  end

  @spec cache_through_write(transaction(), atom(), tuple()) :: :ok
  def cache_through_write(txn, table, record) do
    :ets.insert(:oracle_sync_cache, {{table, elem(record, 1)}, record})
    Database.write(txn, table, record)
  end

  @spec cache_through_write(atom(), tuple()) :: :ok
  def cache_through_write(table, record) do
    :ets.insert(:oracle_sync_cache, {{table, elem(record, 1)}, record})
    Database.dirty_write(table, record)
  end

  @spec cache_through_delete(transaction(), atom(), cache_key()) :: :ok
  def cache_through_delete(txn, table, key) do
    :ets.delete(:oracle_sync_cache, {table, key})
    Database.delete(txn, table, key)
  end

  @spec cache_through_delete(atom(), cache_key()) :: :ok
  def cache_through_delete(table, key) do
    :ets.delete(:oracle_sync_cache, {table, key})
    Database.dirty_delete(table, key)
  end

  @spec cache_through_delete_inactive(transaction(), nil | tuple()) :: :ok
  def cache_through_delete_inactive(_txn, nil), do: :ok

  def cache_through_delete_inactive(txn, m_oracle) do
    pubkey = Model.oracle(m_oracle, :index)
    expire = Model.oracle(m_oracle, :expire)
    cache_through_delete(txn, Model.InactiveOracle, pubkey)
    cache_through_delete(txn, Model.InactiveOracleExpiration, {expire, pubkey})
  end

  @spec oracle_tree!(Blocks.block_hash()) :: tuple()
  def oracle_tree!(block_hash) do
    block_hash
    |> :aec_db.get_block_state()
    |> :aec_trees.oracles()
  end

  @spec expire_oracle(transaction(), Blocks.height(), pubkey()) :: :ok
  def expire_oracle(txn, height, pubkey) do
    cache_through_delete(txn, Model.ActiveOracleExpiration, {height, pubkey})

    oracle_id = Enc.encode(:oracle_pubkey, pubkey)

    case cache_through_read(txn, Model.ActiveOracle, pubkey) do
      {:ok, m_oracle} ->
        if height == Model.oracle(m_oracle, :expire) do
          m_exp = Model.expiration(index: {height, pubkey})
          cache_through_write(txn, Model.InactiveOracle, m_oracle)
          cache_through_write(txn, Model.InactiveOracleExpiration, m_exp)

          cache_through_delete(txn, Model.ActiveOracle, pubkey)
          AeMdw.Ets.inc(:stat_sync_cache, :oracles_expired)

          Log.info("[#{height}] inactivated oracle #{oracle_id}")
        else
          Log.warn("[#{height}] ignored old oracle expiration for #{oracle_id}")
        end

      nil ->
        Log.warn("[#{height}] ignored oracle expiration for #{oracle_id}")
    end

    :ok
  end

  @spec response_mutation(Node.tx(), Blocks.block_index(), Blocks.block_hash(), Txs.txi()) ::
          OracleResponseMutation.t()
  def response_mutation(tx, block_index, block_hash, txi) do
    oracle_pk = :aeo_response_tx.oracle_pubkey(tx)
    query_id = :aeo_response_tx.query_id(tx)
    o_tree = Oracle.oracle_tree!(block_hash)

    try do
      fee =
        oracle_pk
        |> :aeo_state_tree.get_query(query_id, o_tree)
        |> :aeo_query.fee()

      OracleResponseMutation.new(block_index, txi, oracle_pk, fee)
    rescue
      # TreeId = <<OracleId/binary, QId/binary>>,
      # Serialized = aeu_mtrees:get(TreeId, Tree#oracle_tree.otree)
      # raises error on unexisting tree_id
      error ->
        Log.error(error)
        []
    end
  end

  @doc """
  Returns stream of oracle pubkey() that expired at a certain height.
  """
  @spec list_expired_at(Blocks.height()) :: Enumerable.t()
  def list_expired_at(height) do
    Model.InactiveOracleExpiration
    |> Collection.stream(:forward, {{height, <<>>}, {height + 1, <<>>}}, nil)
    |> Stream.map(fn {_height, pubkey} -> pubkey end)
    |> Stream.uniq()
  end
end
