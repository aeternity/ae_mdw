defmodule AeMdw.Db.Sync.Stats do
  @moduledoc """
  Creates stats and sum stats records based on previous height.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Db.Util
  alias AeMdw.Ets
  alias AeMdw.Mnesia

  require Model

  @spec new_mutation(Blocks.height(), boolean()) :: StatsMutation.t()
  def new_mutation(height, all_cached?) do
    m_stat = make_stat(height + 1, all_cached?)
    m_total_stat = make_total_stat(height + 1, m_stat)
    StatsMutation.new(m_stat, m_total_stat)
  end

  #
  # Private functions
  #
  defp make_stat(height, true = _all_cached?) do
    Model.stat(
      index: height,
      inactive_names: get(:inactive_names, 0),
      active_names: get(:active_names, 0),
      active_auctions: get(:active_auctions, 0),
      inactive_oracles: get(:inactive_oracles, 0),
      active_oracles: get(:active_oracles, 0),
      contracts: get(:contracts, 0),
      block_reward: get(:block_reward, 0),
      dev_reward: get(:dev_reward, 0)
    )
  end

  defp make_stat(height, false = _all_cached?) do
    Model.stat(
      inactive_names: prev_inactive_names,
      active_names: prev_active_names,
      active_auctions: prev_active_auctions,
      inactive_oracles: prev_inactive_oracles,
      active_oracles: prev_active_oracles,
      contracts: prev_contracts
    ) = Util.read!(Model.Stat, height - 1)

    {current_active_names, current_active_auctions, current_active_oracles,
     current_inactive_names,
     current_inactive_oracles} =
      :mnesia.async_dirty(fn ->
        {
          Util.count(Model.ActiveName),
          Util.count(Model.AuctionExpiration),
          Util.count(Model.ActiveOracle),
          Util.count(Model.InactiveName),
          Util.count(Model.InactiveOracle)
        }
      end)

    current_contracts =
      Model.ContractCall
      |> Mnesia.dirty_all_keys()
      |> Enum.map(fn {create_txi, _call_txi} -> create_txi end)
      |> Enum.uniq()
      |> length()

    current_block_reward = IntTransfer.read_block_reward(height - 1)
    current_dev_reward = IntTransfer.read_dev_reward(height - 1)

    Model.stat(
      index: height,
      inactive_names: Enum.max([0, current_inactive_names - prev_inactive_names]),
      active_names: Enum.max([0, current_active_names - prev_active_names]),
      active_auctions: Enum.max([0, current_active_auctions - prev_active_auctions]),
      inactive_oracles: Enum.max([0, current_inactive_oracles - prev_inactive_oracles]),
      active_oracles: Enum.max([0, current_active_oracles - prev_active_oracles]),
      contracts: Enum.max([0, current_contracts - prev_contracts]),
      block_reward: current_block_reward,
      dev_reward: current_dev_reward
    )
  end

  defp make_total_stat(
         height,
         Model.stat(
           block_reward: inc_block_reward,
           dev_reward: inc_dev_reward,
           active_auctions: inc_active_auctions,
           active_names: inc_active_names,
           inactive_names: inc_inactive_names,
           active_oracles: inc_active_oracles,
           inactive_oracles: inc_inactive_oracles,
           contracts: inc_contracts
         )
       ) do
    token_supply_delta = AeMdw.Node.token_supply_delta(height)

    Model.total_stat(
      block_reward: prev_block_reward,
      dev_reward: prev_dev_reward,
      total_supply: prev_total_supply,
      active_auctions: prev_active_auctions,
      active_names: prev_active_names,
      inactive_names: prev_inactive_names,
      active_oracles: prev_active_oracles,
      inactive_oracles: prev_inactive_oracles,
      contracts: prev_contracts
    ) = Util.read!(Model.TotalStat, height - 1)

    Model.total_stat(
      index: height,
      block_reward: prev_block_reward + inc_block_reward,
      dev_reward: prev_dev_reward + inc_dev_reward,
      total_supply: prev_total_supply + token_supply_delta + inc_block_reward + inc_dev_reward,
      active_auctions: prev_active_auctions + inc_active_auctions,
      active_names: prev_active_names + inc_active_names,
      inactive_names: prev_inactive_names + inc_inactive_names,
      active_oracles: prev_active_oracles + inc_active_oracles,
      inactive_oracles: prev_inactive_oracles + inc_inactive_oracles,
      contracts: prev_contracts + inc_contracts
    )
  end

  defp get(stat_sync_key, default), do: Ets.get(:stat_sync_cache, stat_sync_key, default)
end
