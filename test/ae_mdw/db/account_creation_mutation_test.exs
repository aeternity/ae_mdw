defmodule AeMdw.Db.AccountCreationMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.AccountCreationMutation
  alias AeMdw.Db.State

  require Model

  test "account creation mutation" do
    state = empty_state()

    state = AccountCreationMutation.execute(AccountCreationMutation.new(<<1::256>>, 1), state)

    key_boundary = {{:total_accounts, :day, -1}, {:total_accounts, :week, nil}}

    all_active_account_statistics =
      state
      |> Collection.stream(Model.Statistic, :forward, key_boundary, nil)
      |> Enum.to_list()

    [_all_account_creations] =
      state
      |> Collection.stream(Model.AccountCreation, nil)
      |> Enum.to_list()

    assert 3 = Enum.count(all_active_account_statistics)

    state = State.commit(state, [AccountCreationMutation.new(<<1::256>>, 5)])

    all_active_account_statistics =
      state
      |> Collection.stream(Model.Statistic, :forward, key_boundary, nil)
      |> Enum.to_list()

    [_all_account_creations] =
      state
      |> Collection.stream(Model.AccountCreation, nil)
      |> Enum.to_list()

    assert 3 = Enum.count(all_active_account_statistics)
  end
end
