defmodule AeMdw.Db.AccountCreationMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.AccountCreationMutation
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.ObjectKeys

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

  test "new account increments :accounts stat" do
    state = empty_state()

    state = AccountCreationMutation.execute(AccountCreationMutation.new(<<10::256>>, 1), state)

    assert State.get_stat(state, :accounts, 0) == 1
  end

  test "counts each new account once, on top of the fallback store's accounts" do
    fallback_state =
      AccountCreationMutation.execute(AccountCreationMutation.new(<<20::256>>, 1), empty_state())

    state =
      [<<20::256>>, <<21::256>>, <<21::256>>]
      |> Enum.reduce(State.new(MemStore.new(fallback_state.store)), fn pubkey, state ->
        AccountCreationMutation.execute(AccountCreationMutation.new(pubkey, 2), state)
      end)

    assert 1 == ObjectKeys.count(fallback_state, Model.AccountCreation)
    assert 2 == ObjectKeys.count(state, Model.AccountCreation)
  end

  test "duplicate account does not increment :accounts stat" do
    state = empty_state()

    state = AccountCreationMutation.execute(AccountCreationMutation.new(<<10::256>>, 1), state)
    state = AccountCreationMutation.execute(AccountCreationMutation.new(<<10::256>>, 2), state)

    assert State.get_stat(state, :accounts, 0) == 1
  end
end
