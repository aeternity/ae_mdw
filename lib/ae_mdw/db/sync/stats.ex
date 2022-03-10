defmodule AeMdw.Db.Sync.Stats do
  @moduledoc """
  Creates stats and sum stats records based on previous height.
  """

  alias AeMdw.Blocks
  alias AeMdw.Database
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Origin
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Ets

  require Model

  @spec new_mutation(Blocks.height(), boolean()) :: StatsMutation.t()
  def new_mutation(height, all_cached?) do
    m_delta_stat = make_delta_stat(height, all_cached?)
    # delta/transitions are only reflected on total stats at height + 1
    m_total_stat = make_total_stat(height + 1, m_delta_stat)
    StatsMutation.new(m_delta_stat, m_total_stat)
  end

  #
  # Private functions
  #
  @spec make_delta_stat(Blocks.height(), boolean()) :: Model.delta_stat()
  defp make_delta_stat(height, true = _all_cached?) do
    Model.delta_stat(
      index: height,
      auctions_started: get(:auctions_started, 0),
      names_activated: get(:names_activated, 0),
      names_expired: get(:names_expired, 0),
      names_revoked: get(:names_revoked, 0),
      oracles_registered: get(:oracles_registered, 0),
      oracles_expired: get(:oracles_expired, 0),
      contracts_created: get(:contracts_created, 0),
      block_reward: get(:block_reward, 0),
      dev_reward: get(:dev_reward, 0)
    )
  end

  defp make_delta_stat(height, false = _all_cached?) do
    Model.total_stat(
      active_auctions: prev_active_auctions,
      active_names: prev_active_names,
      active_oracles: prev_active_oracles,
      contracts: prev_contracts
    ) = Database.fetch!(Model.TotalStat, height)

    current_active_names = Database.count_keys(Model.ActiveName)
    current_active_auctions = Database.count_keys(Model.AuctionExpiration)
    current_active_oracles = Database.count_keys(Model.ActiveOracle)

    {height_revoked_names, height_expired_names} =
      height
      |> Name.list_inactivated_at()
      |> Enum.map(fn plain_name -> Database.fetch!(Model.InactiveName, plain_name) end)
      |> Enum.split_with(fn Model.name(revoke: {{kbi, _mbi}, _txi}) -> kbi == height end)

    all_contracts_count = Origin.count_contracts()

    oracles_expired_count =
      height
      |> Oracle.list_expired_at()
      |> Enum.uniq()
      |> Enum.count()

    current_block_reward = IntTransfer.read_block_reward(height)
    current_dev_reward = IntTransfer.read_dev_reward(height)

    Model.delta_stat(
      index: height,
      auctions_started: max(0, current_active_auctions - prev_active_auctions),
      names_activated: max(0, current_active_names - prev_active_names),
      names_expired: length(height_expired_names),
      names_revoked: length(height_revoked_names),
      oracles_registered: max(0, current_active_oracles - prev_active_oracles),
      oracles_expired: oracles_expired_count,
      contracts_created: all_contracts_count - prev_contracts,
      block_reward: current_block_reward,
      dev_reward: current_dev_reward
    )
  end

  @spec make_total_stat(Blocks.height(), Model.delta_stat()) :: Model.total_stat()
  defp make_total_stat(
         height,
         Model.delta_stat(
           auctions_started: auctions_started,
           names_activated: names_activated,
           names_expired: names_expired,
           names_revoked: names_revoked,
           oracles_registered: oracles_registered,
           oracles_expired: oracles_expired,
           contracts_created: contracts_created,
           block_reward: inc_block_reward,
           dev_reward: inc_dev_reward
         )
       ) do
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
    ) = fetch_total_stat(height - 1)

    token_supply_delta = AeMdw.Node.token_supply_delta(height)
    auctions_expired = get(:auctions_expired, 0)

    Model.total_stat(
      index: height,
      block_reward: prev_block_reward + inc_block_reward,
      dev_reward: prev_dev_reward + inc_dev_reward,
      total_supply: prev_total_supply + token_supply_delta + inc_block_reward + inc_dev_reward,
      active_auctions: max(0, prev_active_auctions + auctions_started - auctions_expired),
      active_names: max(0, prev_active_names + names_activated - (names_expired + names_revoked)),
      inactive_names: prev_inactive_names + names_expired + names_revoked,
      active_oracles: max(0, prev_active_oracles + oracles_registered - oracles_expired),
      inactive_oracles: prev_inactive_oracles + oracles_expired,
      contracts: prev_contracts + contracts_created
    )
  end

  defp get(stat_sync_key, default), do: Ets.get(:stat_sync_cache, stat_sync_key, default)

  defp fetch_total_stat(0) do
    Model.total_stat()
  end

  defp fetch_total_stat(height) do
    Database.fetch!(Model.TotalStat, height)
  end
end
