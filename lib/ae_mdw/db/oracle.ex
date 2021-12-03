defmodule AeMdw.Db.Oracle do
  @moduledoc """
  Cache through operations for active and inactive oracles.
  """
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.OraclesExpirationMutation

  require Ex2ms
  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

  @type pubkey() :: <<_::256>>
  @typep cache_key() :: pubkey() | {pos_integer(), pubkey()}

  @spec source(atom(), :expiration) ::
          Model.ActiveOracleExpiration | Model.InactiveOracleExpiration
  def source(Model.ActiveName, :expiration), do: Model.ActiveOracleExpiration
  def source(Model.InactiveName, :expiration), do: Model.InactiveOracleExpiration

  @spec locate(pubkey()) :: {tuple(), Model.ActiveOracle | Model.InactiveOracle} | nil
  def locate(pubkey) do
    map_ok_nil(cache_through_read(Model.ActiveOracle, pubkey), &{&1, Model.ActiveOracle}) ||
      map_ok_nil(cache_through_read(Model.InactiveOracle, pubkey), &{&1, Model.InactiveOracle})
  end

  # for use outside mnesia TX - doesn't modify cache, just looks into it
  @spec cache_through_read(atom(), cache_key()) :: {:ok, tuple()} | nil
  def cache_through_read(table, key) do
    case :ets.lookup(:oracle_sync_cache, {table, key}) do
      [{_, record}] -> {:ok, record}
      [] -> map_one_nil(read(table, key), &{:ok, &1})
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
    mns_lookup = fn -> lookup.(prev(table, key), & &1, nf, nf) end
    lookup.(:ets.prev(:oracle_sync_cache, {table, key}), &elem(&1, 1), mns_lookup, mns_lookup)
  end

  # for use inside mnesia TX - caches writes & deletes in the same TX
  @spec cache_through_write(atom(), tuple()) :: :ok
  def cache_through_write(table, record) do
    :ets.insert(:oracle_sync_cache, {{table, elem(record, 1)}, record})
    :mnesia.write(table, record, :write)
  end

  @spec cache_through_delete(atom(), cache_key()) :: :ok
  def cache_through_delete(table, key) do
    :ets.delete(:oracle_sync_cache, {table, key})
    :mnesia.delete(table, key, :write)
  end

  @spec cache_through_delete_inactive(nil | tuple()) :: :ok
  def cache_through_delete_inactive(nil), do: :ok

  def cache_through_delete_inactive(m_oracle) do
    pubkey = Model.oracle(m_oracle, :index)
    expire = Model.oracle(m_oracle, :expire)
    cache_through_delete(Model.InactiveOracle, pubkey)
    cache_through_delete(Model.InactiveOracleExpiration, {expire, pubkey})
  end

  @spec oracle_tree!({pos_integer(), integer()}) :: tuple()
  def oracle_tree!({_, _} = block_index) do
    block_index
    |> read_block!
    |> Model.block(:hash)
    |> :aec_db.get_block_state()
    |> :aec_trees.oracles()
  end

  @spec expirations_mutation(Blocks.height()) :: OraclesExpirationMutation.t()
  def expirations_mutation(height) do
    oracle_mspec =
      Ex2ms.fun do
        Model.expiration(index: {^height, pubkey}) -> pubkey
      end

    expired_pubkeys = :mnesia.dirty_select(Model.ActiveOracleExpiration, oracle_mspec)

    OraclesExpirationMutation.new(height, expired_pubkeys)
  end

  @spec expire_oracle(Blocks.height(), pubkey()) :: :ok
  def expire_oracle(height, pubkey) do
    cache_through_delete(Model.ActiveOracleExpiration, {height, pubkey})

    {:ok, m_oracle} = cache_through_read(Model.ActiveOracle, pubkey)

    m_exp = Model.expiration(index: {height, pubkey})
    cache_through_write(Model.InactiveOracle, m_oracle)
    cache_through_write(Model.InactiveOracleExpiration, m_exp)

    cache_through_delete(Model.ActiveOracle, pubkey)
    AeMdw.Ets.inc(:stat_sync_cache, :inactive_oracles)
    AeMdw.Ets.dec(:stat_sync_cache, :active_oracles)

    :ok
  end
end
