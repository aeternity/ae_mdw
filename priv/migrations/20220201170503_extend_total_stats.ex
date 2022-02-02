defmodule AeMdw.Migrations.ExtendTotalStats do
  @moduledoc """
  Adds sum of active auctions, active and inactive names, active and inactive oracles
  and contracts to Model.total_stats.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Log

  require Ex2ms
  require Model

  @doc """
  Total stats.
  """
  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    any_spec =
      Ex2ms.fun do
        record -> record
      end

    stats = Util.select(Model.Stat, any_spec)

    zero_total_stat =
      Model.total_stat(
        index: 0,
        block_reward: 0,
        dev_reward: 0,
        total_supply: AeMdw.Node.token_supply_delta(0),
        active_auctions: 0,
        active_names: 0,
        inactive_names: 0,
        active_oracles: 0,
        inactive_oracles: 0,
        contracts: 0
      )

    total_stat_list =
      Enum.reduce(stats, [zero_total_stat], fn m_stat, list ->
        Model.stat(
          index: height,
          inactive_names: inc_inactive_names,
          active_names: inc_active_names,
          active_auctions: inc_active_auctions,
          inactive_oracles: inc_inactive_oracles,
          active_oracles: inc_active_oracles,
          contracts: inc_contracts,
          block_reward: inc_block_reward,
          dev_reward: inc_dev_reward
        ) = m_stat

        Model.total_stat(
          inactive_names: prev_inactive_names,
          active_names: prev_active_names,
          active_auctions: prev_active_auctions,
          inactive_oracles: prev_inactive_oracles,
          active_oracles: prev_active_oracles,
          contracts: prev_contracts,
          block_reward: prev_block_reward,
          dev_reward: prev_dev_reward,
          total_supply: prev_total_supply
        ) = List.first(list)

        token_supply_delta = AeMdw.Node.token_supply_delta(height)

        m_total_stat =
          Model.total_stat(
            index: height,
            block_reward: prev_block_reward + inc_block_reward,
            dev_reward: prev_dev_reward + inc_dev_reward,
            total_supply:
              prev_total_supply + token_supply_delta + inc_block_reward + inc_dev_reward,
            active_auctions: prev_active_auctions + inc_active_auctions,
            active_names: prev_active_names + inc_active_names,
            inactive_names: prev_inactive_names + inc_inactive_names,
            active_oracles: prev_active_oracles + inc_active_oracles,
            inactive_oracles: prev_inactive_oracles + inc_inactive_oracles,
            contracts: prev_contracts + inc_contracts
          )

        [m_total_stat | list]
      end)

    [^zero_total_stat | total_stat_list] = Enum.reverse(total_stat_list)

    total_stat_list
    |> Enum.chunk_every(100)
    |> Enum.each(fn chunk ->
      :mnesia.sync_dirty(fn ->
        write_total_stat_chunk(chunk)
      end)
    end)

    indexed_count = length(total_stat_list)
    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end

  defp write_total_stat_chunk(chunk) do
    Enum.each(chunk, fn m_total_stat ->
      :mnesia.write(Model.TotalStat, m_total_stat, :write)
    end)
  end
end
