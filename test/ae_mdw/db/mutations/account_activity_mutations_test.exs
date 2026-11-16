defmodule AeMdw.Db.Mutation.AccountActivityMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.AccountActivityMutation

  require Model

  test "account activity mutation" do
    state = empty_state()

    state = AccountActivityMutation.execute(AccountActivityMutation.new(<<1::256>>, 1), state)

    key_boundary = {{:active_accounts, :day, -1}, {:active_accounts, :week, nil}}

    all_active_account_statistics =
      state
      |> Collection.stream(Model.Statistic, :forward, key_boundary, nil)
      |> Enum.to_list()

    [_all_account_activities] =
      state
      |> Collection.stream(Model.AccountActivity, nil)
      |> Enum.to_list()

    assert 3 = Enum.count(all_active_account_statistics)

    one_day_in_milliseconds = 1000 * 60 * 60 * 24

    state =
      AccountActivityMutation.execute(
        AccountActivityMutation.new(<<1::256>>, 1 + one_day_in_milliseconds),
        state
      )

    all_active_account_statistics =
      state
      |> Collection.stream(Model.Statistic, :forward, key_boundary, nil)
      |> Enum.to_list()

    all_account_activities =
      state
      |> Collection.stream(Model.AccountActivity, nil)
      |> Enum.to_list()

    assert 4 = Enum.count(all_active_account_statistics)
    assert 2 = Enum.count(all_account_activities)
  end

  test "account activity on the same day doesn't increase the active accounts" do
    state =
      Enum.reduce([1, 2], empty_state(), fn time, state ->
        AccountActivityMutation.execute(AccountActivityMutation.new(<<1::256>>, time), state)
      end)

    assert %{{:day, 0} => 1, {:week, 0} => 1, {:month, 0} => 1} ==
             active_accounts_counts(state)

    assert 2 = state |> Collection.stream(Model.AccountActivity, nil) |> Enum.count()
  end

  test "account activity on a new month within the same week increases the day and month active accounts" do
    one_day_in_milliseconds = 1000 * 60 * 60 * 24

    # 1970-01-31 and 1970-02-01 are both in the week 4
    state =
      Enum.reduce([30, 31], empty_state(), fn day, state ->
        AccountActivityMutation.execute(
          AccountActivityMutation.new(<<1::256>>, day * one_day_in_milliseconds),
          state
        )
      end)

    assert %{
             {:day, 30} => 1,
             {:day, 31} => 1,
             {:week, 4} => 1,
             {:month, 0} => 1,
             {:month, 1} => 1
           } == active_accounts_counts(state)
  end

  test "account activity of another account on the same day doesn't count as this account's" do
    # so that account 1's lookup runs into account 2's activity
    state =
      Enum.reduce([<<2::256>>, <<1::256>>], empty_state(), fn pubkey, state ->
        AccountActivityMutation.execute(AccountActivityMutation.new(pubkey, 1), state)
      end)

    assert %{{:day, 0} => 2, {:week, 0} => 2, {:month, 0} => 2} ==
             active_accounts_counts(state)
  end

  test "account activity right before and after the start of a day counts for its own day" do
    one_day_in_milliseconds = 1000 * 60 * 60 * 24

    # the last millisecond of day 0, then the first two milliseconds of day 1
    state =
      Enum.reduce([-1, 0, 1], empty_state(), fn offset, state ->
        time = one_day_in_milliseconds + offset
        AccountActivityMutation.execute(AccountActivityMutation.new(<<1::256>>, time), state)
      end)

    assert %{{:day, 0} => 1, {:day, 1} => 1, {:week, 0} => 1, {:month, 0} => 1} ==
             active_accounts_counts(state)
  end

  test "account activity before a later one of the same account counts for its own day" do
    one_day_in_milliseconds = 1000 * 60 * 60 * 24

    state =
      Enum.reduce([one_day_in_milliseconds, 1], empty_state(), fn time, state ->
        AccountActivityMutation.execute(AccountActivityMutation.new(<<1::256>>, time), state)
      end)

    assert %{{:day, 0} => 1, {:day, 1} => 1, {:week, 0} => 1, {:month, 0} => 1} ==
             active_accounts_counts(state)
  end

  defp active_accounts_counts(state) do
    key_boundary = {{:active_accounts, :day, -1}, {:active_accounts, :week, nil}}

    state
    |> Collection.stream(Model.Statistic, :forward, key_boundary, nil)
    |> Map.new(fn {:active_accounts, interval_by, interval_start} = index ->
      Model.statistic(count: count) = State.fetch!(state, Model.Statistic, index)

      {{interval_by, interval_start}, count}
    end)
  end
end
