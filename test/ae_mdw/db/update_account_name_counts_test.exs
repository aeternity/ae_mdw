defmodule AeMdw.Db.UpdateAccountNameCountsTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.NameClaimMutation
  alias AeMdw.Db.NameRevokeMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.UpdateAccountNameCountsMutation

  require Model

  setup do
    first_owner = <<1::256>>
    second_owner = <<2::256>>
    third_owner = <<3::256>>

    state =
      1..30
      |> Enum.reduce(State.new(), fn i, state_acc ->
        owner =
          case rem(i, 3) do
            0 -> first_owner
            1 -> second_owner
            2 -> third_owner
          end

        plain_name = "SomeLongTestName#{i}.test"

        mutation =
          NameClaimMutation.new(plain_name, <<i::256>>, owner, 1, true, {1, 1}, {1, -1}, 7)

        State.commit(state_acc, [mutation])
      end)

    %{
      state: state,
      first_owner: first_owner,
      second_owner: second_owner,
      third_owner: third_owner
    }
  end

  test "update counts when active names are updated", %{state: state} do
    all_active_names_owners =
      state
      |> Collection.stream(Model.AccountNamesCount, :forward, nil, nil)
      |> Enum.map(& &1)

    assert [] = all_active_names_owners

    state =
      State.commit(state, [UpdateAccountNameCountsMutation.new()])

    all_active_names_owners =
      state
      |> Collection.stream(Model.AccountNamesCount, :forward, nil, nil)

    assert 3 = Enum.count(all_active_names_owners)

    assert 30 =
             Enum.reduce(all_active_names_owners, 0, fn index, acc ->
               {:ok, Model.account_names_count(count: count)} =
                 State.get(state, Model.AccountNamesCount, index)

               acc + count
             end)

    revoke_mutations =
      1..10
      |> Enum.reduce([], fn i, acc ->
        mutation =
          NameRevokeMutation.new(<<i::256>>, {1, 1}, {1, 1})

        [mutation | acc]
      end)

    state =
      state
      |> State.commit(revoke_mutations)
      |> State.commit([UpdateAccountNameCountsMutation.new()])

    assert 3 = Enum.count(all_active_names_owners)

    assert 20 =
             Enum.reduce(all_active_names_owners, 0, fn index, acc ->
               {:ok, Model.account_names_count(count: count)} =
                 State.get(state, Model.AccountNamesCount, index)

               acc + count
             end)
  end
end
