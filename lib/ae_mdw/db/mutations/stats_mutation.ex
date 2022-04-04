defmodule AeMdw.Db.StatsMutation do
  @moduledoc """
  Inserts statistics about this generation into Model.DeltaStat table.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Blocks
  alias AeMdw.Database
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:height, :all_cached?]

  @type t() :: %__MODULE__{
          height: Blocks.height(),
          all_cached?: boolean()
        }

  @spec new(Blocks.height(), boolean()) :: t()
  def new(height, all_cached?) do
    %__MODULE__{
      height: height,
      all_cached?: all_cached?
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{height: height, all_cached?: all_cached?}, state) do
    m_delta_stat = make_delta_stat(state, height, all_cached?)
    # delta/transitions are only reflected on total stats at height + 1
    m_total_stat = make_total_stat(state, height + 1, m_delta_stat)

    state
    |> State.put(Model.DeltaStat, m_delta_stat)
    |> State.put(Model.TotalStat, m_total_stat)
  end

  #
  # Private functions
  #
  @spec make_delta_stat(State.t(), Blocks.height(), boolean()) :: Model.delta_stat()
  defp make_delta_stat(state, height, true = _all_cached?) do
    Model.delta_stat(
      index: height,
      auctions_started: get(state, :auctions_started, 0),
      names_activated: get(state, :names_activated, 0),
      names_expired: get(state, :names_expired, 0),
      names_revoked: get(state, :names_revoked, 0),
      oracles_registered: get(state, :oracles_registered, 0),
      oracles_expired: get(state, :oracles_expired, 0),
      contracts_created: get(state, :contracts_created, 0),
      block_reward: get(state, :block_reward, 0),
      dev_reward: get(state, :dev_reward, 0)
    )
  end

  defp make_delta_stat(_state, height, false = _all_cached?) do
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
      |> Enum.split_with(fn Model.name(revoke: revoke) ->
        if revoke do
          {{kbi, _mbi}, _txi} = revoke
          kbi == height
        else
          false
        end
      end)

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
      contracts_created: max(0, all_contracts_count - prev_contracts),
      block_reward: current_block_reward,
      dev_reward: current_dev_reward
    )
  end

  @spec make_total_stat(State.t(), Blocks.height(), Model.delta_stat()) :: Model.total_stat()
  defp make_total_stat(
         state,
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

    token_supply_delta = AeMdw.Node.token_supply_delta(height - 1)
    auctions_expired = get(state, :auctions_expired, 0)

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

  defp get(state, stat_sync_key, default), do: State.get_stat(state, stat_sync_key, default)

  defp fetch_total_stat(0) do
    Model.total_stat()
  end

  defp fetch_total_stat(height) do
    Database.fetch!(Model.TotalStat, height)
  end
end
