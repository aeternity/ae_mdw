defmodule AeMdw.Db.Sync.Stat do
  alias AeMdw.Db.Model
  require Model

  import AeMdw.Ets
  import AeMdw.Util

  @stat_field %{
    inactive_names: 1,
    active_names: 2,
    active_auctions: 3,
    inactive_oracles: 4,
    active_oracles: 5,
    contracts: 6,
    block_reward: 7,
    dev_reward: 8
  }

  ##########

  def store(height) do
    h1 = height + 1
    m_stat_new = merge_stat(get_stat(height))
    :mnesia.write(Model.Stat, Model.stat(m_stat_new, index: h1), :write)
    h1
  end

  def merge_stat(stat), do: merge(:stat_sync_cache, @stat_field, stat)

  def merge(table, field_map, db_rec) do
    foldl(table, db_rec, fn {key, val}, acc ->
      pos = Map.get(field_map, key)

      (is_integer(pos) &&
         :erlang.setelement(pos + 2, acc, elem(acc, pos + 1) + val)) ||
        acc
    end)
  end

  def get_stat(height) when height > 0,
    do: AeMdw.Db.Util.read!(Model.Stat, height)

  def get_stat(0),
    do: Model.stat(index: 0)

  ##########

  def sum_store(height) do
    h1 = height + 1
    inc_block_reward = get(:stat_sync_cache, :block_reward, 0)
    inc_dev_reward = get(:stat_sync_cache, :dev_reward, 0)
    inc_total_supply = AeMdw.Node.token_supply_delta(h1)
    {:sum_stat, ^height, block_reward, dev_reward, total_supply} = get_sum_stat(height)

    m_sum =
      Model.sum_stat(
        index: h1,
        block_reward: block_reward + inc_block_reward,
        dev_reward: dev_reward + inc_dev_reward,
        total_supply: total_supply + inc_total_supply + inc_block_reward + inc_dev_reward
      )

    :mnesia.write(Model.SumStat, m_sum, :write)
  end

  def get_sum_stat(height) when height >= 0,
    do: AeMdw.Db.Util.read!(Model.SumStat, height)
end
