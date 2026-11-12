defmodule AeMdw.Accounts do
  @moduledoc """
    Module for account related operations
  """
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats, as: SyncStats
  alias AeMdw.Node.Db

  require Model

  @spec maybe_increase_creation_statistics(State.t(), Db.pubkey(), Blocks.time()) :: State.t()
  def maybe_increase_creation_statistics(state, pubkey, time) do
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
        |> State.inc_stat(:accounts)

      _account_creation ->
        state
    end
  end

  @spec account_activity(State.t(), Db.pubkey(), Blocks.time()) :: State.t()
  def account_activity(state, pubkey, time) do
    initial_intervals = SyncStats.time_intervals(time)

    [{:day, day_boundary} | week_and_month_boundaries] =
      SyncStats.key_boundaries_for_intervals(pubkey, initial_intervals)

    # the day range lies within the week and month ranges
    state =
      if active_in?(state, day_boundary) do
        state
      else
        week_and_month_boundaries
        |> Enum.reject(fn {_interval_type, key_boundary} -> active_in?(state, key_boundary) end)
        |> Enum.reduce(
          increment_active_accounts(state, :day, initial_intervals),
          fn {interval_type, _key_boundary}, state ->
            increment_active_accounts(state, interval_type, initial_intervals)
          end
        )
      end

    State.put(state, Model.AccountActivity, Model.account_activity(index: {pubkey, time}))
  end

  # State.next/3 starts after the given key
  defp active_in?(state, {{pubkey, first_time}, {pubkey, last_time}}) do
    case State.next(state, Model.AccountActivity, {pubkey, first_time - 1}) do
      {:ok, {^pubkey, time}} -> time <= last_time
      _none_or_other_account -> false
    end
  end

  defp increment_active_accounts(state, interval_type, intervals) do
    index = {:active_accounts, interval_type, Keyword.fetch!(intervals, interval_type)}

    State.update(
      state,
      Model.Statistic,
      index,
      fn Model.statistic(count: count) = statistics ->
        Model.statistic(statistics, count: count + 1)
      end,
      Model.statistic(index: index, count: 0)
    )
  end
end
