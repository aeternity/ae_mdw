defmodule AeMdw.Db.StatsMutation do
  @moduledoc """
  Inserts statistics about this generation into Model.DeltaStat table.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Blocks
  alias AeMdw.Channels
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Oracle
  alias AeMdw.Stats
  alias AeMdw.Txs
  alias AeMdw.Util

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:height, :key_hash, :from_txi, :next_txi, :tps, :all_cached?]

  @typep txi() :: Txs.txi()

  @type t() :: %__MODULE__{
          height: Blocks.height(),
          key_hash: Blocks.block_hash(),
          from_txi: txi(),
          next_txi: txi(),
          tps: Stats.tps(),
          all_cached?: boolean()
        }

  @spec new(Blocks.height(), Blocks.block_hash(), txi(), txi(), Stats.tps(), boolean()) :: t()
  def new(height, key_hash, from_txi, next_txi, tps, all_cached?) do
    %__MODULE__{
      height: height,
      key_hash: key_hash,
      from_txi: from_txi,
      next_txi: next_txi,
      tps: tps,
      all_cached?: all_cached?
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          height: height,
          key_hash: key_hash,
          from_txi: from_txi,
          next_txi: next_txi,
          tps: tps,
          all_cached?: all_cached?
        },
        state
      ) do
    m_delta_stat = make_delta_stat(state, height, from_txi, next_txi, all_cached?)
    # delta/transitions are only reflected on total stats at height + 1
    m_total_stat = make_total_stat(state, height + 1, m_delta_stat)

    state
    |> State.put(Model.DeltaStat, m_delta_stat)
    |> State.put(Model.TotalStat, m_total_stat)
    |> State.update(Model.Stat, Stats.max_tps_key(), fn
      Model.stat(payload: {max_tps, _tps_block_hash}) = stat ->
        if tps >= max_tps do
          Model.stat(stat, payload: {tps, key_hash})
        else
          stat
        end

      nil ->
        Model.stat(index: Stats.max_tps_key(), payload: {tps, key_hash})
    end)
  end

  #
  # Private functions
  #
  @spec make_delta_stat(State.t(), Blocks.height(), txi(), txi(), boolean()) :: Model.delta_stat()
  defp make_delta_stat(state, height, _from_txi, _next_txi, true = _all_cached?) do
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
      dev_reward: get(state, :dev_reward, 0),
      locked_in_auctions: get(state, :locked_in_auctions, 0),
      burned_in_auctions: get(state, :burned_in_auctions, 0),
      channels_opened: get(state, :channels_opened, 0),
      channels_closed: get(state, :channels_closed, 0),
      locked_in_channels: get(state, :locked_in_channels, 0)
    )
  end

  defp make_delta_stat(state, height, from_txi, next_txi, false = _all_cached?) do
    Model.total_stat(
      active_auctions: prev_active_auctions,
      active_names: prev_active_names,
      active_oracles: prev_active_oracles,
      contracts: prev_contracts
    ) = State.fetch!(state, Model.TotalStat, height)

    current_active_names = State.count_keys(state, Model.ActiveName)
    current_active_auctions = State.count_keys(state, Model.AuctionExpiration)
    current_active_oracles = State.count_keys(state, Model.ActiveOracle)
    channels_opened = Channels.channels_opened_count(state, from_txi, next_txi)
    channels_closed = Channels.channels_closed_count(state, from_txi, next_txi)

    {height_revoked_names, height_expired_names} =
      state
      |> Name.list_inactivated_at(height)
      |> Enum.map(fn plain_name -> State.fetch!(state, Model.InactiveName, plain_name) end)
      |> Enum.split_with(fn Model.name(revoke: revoke) ->
        if revoke do
          {{kbi, _mbi}, _txi} = revoke
          kbi == height
        else
          false
        end
      end)

    all_contracts_count = Origin.count_contracts(state)

    oracles_expired_count =
      state
      |> Oracle.list_expired_at(height)
      |> Enum.count()

    current_block_reward = IntTransfer.read_block_reward(state, height)
    current_dev_reward = IntTransfer.read_dev_reward(state, height)

    burned_in_auctions = height_int_amount(state, height, :lock_name)
    spent_in_auctions = height_int_amount(state, height, :spend_name)
    refund_in_auctions = height_int_amount(state, height, :refund_name)
    locked_in_auctions = spent_in_auctions - refund_in_auctions
    locked_in_channels = height_int_amount(state, height, :lock_channel)

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
      dev_reward: current_dev_reward,
      locked_in_auctions: locked_in_auctions,
      burned_in_auctions: burned_in_auctions,
      channels_opened: channels_opened,
      channels_closed: channels_closed,
      locked_in_channels: locked_in_channels
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
           dev_reward: inc_dev_reward,
           locked_in_auctions: locked_in_auctions,
           burned_in_auctions: burned_in_auctions,
           channels_opened: channels_opened,
           channels_closed: channels_closed,
           locked_in_channels: locked_in_channels
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
      contracts: prev_contracts,
      locked_in_auctions: prev_locked_in_auctions,
      burned_in_auctions: prev_burned_in_acutions,
      open_channels: prev_open_channels,
      locked_in_channels: prev_locked_in_channels
    ) = fetch_total_stat(state, height - 1)

    token_supply_delta = AeMdw.Node.token_supply_delta(height - 1)
    auctions_expired = get(state, :auctions_expired, 0)
    new_oracles_expired = get(state, :new_oracles_expired, 0)
    old_oracles_registered = get(state, :old_oracles_registered, 0)

    Model.total_stat(
      index: height,
      block_reward: prev_block_reward + inc_block_reward,
      dev_reward: prev_dev_reward + inc_dev_reward,
      total_supply: prev_total_supply + token_supply_delta + inc_block_reward + inc_dev_reward,
      active_auctions: max(0, prev_active_auctions + auctions_started - auctions_expired),
      active_names: max(0, prev_active_names + names_activated - (names_expired + names_revoked)),
      inactive_names: prev_inactive_names + names_expired + names_revoked,
      active_oracles: max(0, prev_active_oracles + oracles_registered - oracles_expired),
      inactive_oracles:
        max(0, prev_inactive_oracles - old_oracles_registered + new_oracles_expired),
      contracts: prev_contracts + contracts_created,
      locked_in_auctions: prev_locked_in_auctions + locked_in_auctions,
      burned_in_auctions: prev_burned_in_acutions + burned_in_auctions,
      open_channels: prev_open_channels + channels_opened - channels_closed,
      locked_in_channels: prev_locked_in_channels + locked_in_channels
    )
  end

  defp get(state, stat_sync_key, default), do: State.get_stat(state, stat_sync_key, default)

  defp fetch_total_stat(_state, 0) do
    Model.total_stat()
  end

  defp fetch_total_stat(state, height) do
    State.fetch!(state, Model.TotalStat, height)
  end

  defp height_int_amount(state, height, kind) do
    kind_str = "fee_#{kind}"

    state
    |> Collection.stream(Model.KindIntTransferTx, {kind_str, {height, -1}, Util.min_bin(), nil})
    |> Stream.take_while(&match?({^kind_str, {^height, _mbi}, _address, _ref_txi}, &1))
    |> Stream.map(fn {kind_str, block_index, address, ref_txi} ->
      {block_index, kind_str, address, ref_txi}
    end)
    |> Stream.map(&State.fetch!(state, Model.IntTransferTx, &1))
    |> Enum.reduce(0, fn Model.int_transfer_tx(amount: amount), amount_acc ->
      amount_acc + amount
    end)
  end
end
