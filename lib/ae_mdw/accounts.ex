defmodule AeMdw.Accounts do
  @moduledoc """
    Module for account related operations
  """
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats, as: SyncStats
  alias AeMdw.Node.Db

  require Model

  @spec maybe_increase_creation_statistics(State.t(), Db.pubkey(), Blocks.time(), Blocks.height()) ::
          State.t()
  def maybe_increase_creation_statistics(state, pubkey, time, height) do
    state
    |> State.get(Model.AccountCreation, pubkey)
    |> case do
      :not_found ->
        state
        |> State.put(
          Model.AccountCreation,
          Model.account_creation(index: pubkey, creation_time: time)
        )
        |> SyncStats.increment_statistics(:total_accounts, time, 1)
        |> SyncStats.increment_height_statistics(:total_accounts, height, 1)
        |> State.inc_stat(:total_accounts)

      _account_creation ->
        state
    end
  end

  @spec account_activity(State.t(), Db.pubkey(), Blocks.time()) :: State.t()
  def account_activity(state, pubkey, time) do
    initial_intervals = SyncStats.time_intervals(time)

    pubkey
    |> SyncStats.key_boundaries_for_intervals(initial_intervals)
    |> Enum.reduce(state, fn {interval_type, key_boundary}, state ->
      state
      |> Collection.stream(Model.AccountActivity, :forward, key_boundary, nil)
      |> Enum.take(1)
      |> case do
        [] ->
          index =
            {:active_accounts, interval_type, Keyword.fetch!(initial_intervals, interval_type)}

          State.update(
            state,
            Model.Statistic,
            index,
            fn Model.statistic(count: count) = statistics ->
              Model.statistic(statistics, count: count + 1)
            end,
            Model.statistic(index: index, count: 0)
          )

        _account_activity ->
          state
      end
    end)
    |> State.put(Model.AccountActivity, Model.account_activity(index: {pubkey, time}))
  end
end
