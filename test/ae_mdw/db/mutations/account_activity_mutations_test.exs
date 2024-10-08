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
end
