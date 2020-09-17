defmodule AeMdw.Db.Oracle do
  alias AeMdw.Node, as: AE
  alias AeMdw.Db.Model

  require Model
  require Ex2ms

  import AeMdw.{Util, Db.Util}

  ##########

  def source(Model.ActiveName, :expiration), do: Model.ActiveOracleExpiration
  def source(Model.InactiveName, :expiration), do: Model.InactiveOracleExpiration

  def locate(pubkey) do
    map_ok_nil(cache_through_read(Model.ActiveOracle, pubkey), &{&1, Model.ActiveOracle}) ||
      map_ok_nil(cache_through_read(Model.InactiveOracle, pubkey), &{&1, Model.InactiveOracle})
  end

  # for use outside mnesia TX - doesn't modify cache, just looks into it
  def cache_through_read(table, key) do
    case :ets.lookup(:oracle_sync_cache, {table, key}) do
      [{_, record}] -> {:ok, record}
      [] -> map_one_nil(read(table, key), &{:ok, &1})
    end
  end

  def cache_through_read!(table, key),
    do: ok_nil(cache_through_read(table, key)) || raise("#{inspect(key)} not found in #{table}")

  def cache_through_prev(table, key),
    do: cache_through_prev(table, key, &(elem(key, 0) == elem(&1, 0)))

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
  def cache_through_write(table, record) do
    :ets.insert(:oracle_sync_cache, {{table, elem(record, 1)}, record})
    :mnesia.write(table, record, :write)
  end

  def cache_through_delete(table, key) do
    :ets.delete(:oracle_sync_cache, {table, key})
    :mnesia.delete(table, key, :write)
  end

  def cache_through_delete_inactive(nil), do: nil

  def cache_through_delete_inactive(m_oracle) do
    pubkey = Model.oracle(m_oracle, :index)
    expire = Model.oracle(m_oracle, :expire)
    cache_through_delete(Model.InactiveOracle, pubkey)
    cache_through_delete(Model.InactiveOracleExpiration, {expire, pubkey})
  end

  ##########

  # def detail(pubkey, block_index) do
  # end

  def oracle_tree!({_, _} = block_index) do
    block_index
    |> read_block!
    |> Model.block(:hash)
    |> :aec_db.get_block_state()
    |> :aec_trees.oracles()
  end

  def otree(oracle_tree) when elem(oracle_tree, 0) == :oracle_tree,
    do: elem(oracle_tree, AE.aeo_tree_pos(:otree))

  def otree({_, _} = block_index),
    do: otree(oracle_tree!(block_index))

  def cache(oracle_tree) when elem(oracle_tree, 0) == :oracle_tree,
    do: elem(oracle_tree, AE.aeo_tree_pos(:cache))

  def cache({_, _} = block_index),
    do: cache(oracle_tree!(block_index))
end
