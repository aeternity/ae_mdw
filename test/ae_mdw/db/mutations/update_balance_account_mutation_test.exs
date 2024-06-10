defmodule AeMdw.UpdateBalanceAccountMutationTest do
  use AeMdw.Db.MutationCase, async: false

  alias AeMdw.Collection
  alias AeMdw.Db.DbStore
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.UpdateBalanceAccountMutation
  alias AeMdw.Sync.WealthRank
  require Model

  setup do
    global_state_ref = :persistent_term.get(:global_state, nil)

    on_exit(fn ->
      :persistent_term.put(:global_state, global_state_ref)
    end)
  end

  test "Adds balances to wealth tables" do
    account_pk1 = :crypto.strong_rand_bytes(32)
    account_pk2 = :crypto.strong_rand_bytes(32)
    account_pk3 = :crypto.strong_rand_bytes(32)
    amount11 = Enum.random(100_000_000..999_999_999)
    amount12 = Enum.random(100_000_000..999_999_999)
    amount21 = Enum.random(100_000_000..999_999_999)
    amount31 = Enum.random(100_000_000..999_999_999)

    state = DbStore.new() |> State.new()

    state =
      WealthRank.update_balances(state, [
        {account_pk1, amount11},
        {account_pk2, amount21}
      ])

    assert state
           |> Collection.stream(Model.BalanceAccount, :backward, {nil, nil}, nil)
           |> Enum.count() == 2

    assert state
           |> Collection.stream(Model.AccountBalance, :backward, {nil, nil}, nil)
           |> Enum.count() == 2

    update_accout_pk1_mutation = UpdateBalanceAccountMutation.new(account_pk1, amount12)
    add_account_pk3_mutation = UpdateBalanceAccountMutation.new(account_pk3, amount31)

    state = Mutation.execute(update_accout_pk1_mutation, state)
    state = Mutation.execute(add_account_pk3_mutation, state)

    assert state
           |> Collection.stream(Model.BalanceAccount, :backward, {nil, nil}, nil)
           |> Enum.count() == 3

    assert :not_found =
             State.get(state, Model.BalanceAccount, {amount11, account_pk1})

    assert {:ok, Model.balance_account(index: {^amount12, ^account_pk1})} =
             State.get(state, Model.BalanceAccount, {amount12, account_pk1})

    assert {:ok, Model.balance_account(index: {^amount21, ^account_pk2})} =
             State.get(state, Model.BalanceAccount, {amount21, account_pk2})

    assert {:ok, Model.balance_account(index: {^amount31, ^account_pk3})} =
             State.get(state, Model.BalanceAccount, {amount31, account_pk3})

    assert state
           |> Collection.stream(Model.AccountBalance, :backward, {nil, nil}, nil)
           |> Enum.count() == 3

    assert {:ok, Model.account_balance(index: ^account_pk1, balance: ^amount12)} =
             State.get(state, Model.AccountBalance, account_pk1)

    assert {:ok, Model.account_balance(index: ^account_pk2, balance: ^amount21)} =
             State.get(state, Model.AccountBalance, account_pk2)

    assert {:ok, Model.account_balance(index: ^account_pk3, balance: ^amount31)} =
             State.get(state, Model.AccountBalance, account_pk3)

    delete_mutation =
      DeleteKeysMutation.new(%{
        Model.AccountBalance => [account_pk1, account_pk2, account_pk3],
        Model.BalanceAccount => [
          {amount12, account_pk1},
          {amount21, account_pk2},
          {amount31, account_pk3}
        ]
      })

    Mutation.execute(delete_mutation, state)
  end

  test "Gets correct balances if there are a lot of records" do
    account_pks = Enum.map(1..100, fn _index -> :crypto.strong_rand_bytes(32) end)
    amounts = Enum.map(1..100, fn _index -> Enum.random(100_000_000..999_999_999) end)
    account_amounts = Enum.zip(account_pks, amounts)

    state = DbStore.new() |> State.new()

    state = WealthRank.update_balances(state, account_amounts)

    assert state
           |> Collection.stream(Model.BalanceAccount, :backward, {nil, nil}, nil)
           |> Enum.count() == 100

    assert state
           |> Collection.stream(Model.AccountBalance, :backward, {nil, nil}, nil)
           |> Enum.count() == 100

    state =
      Enum.reduce(account_amounts, state, fn {account_pk, balance}, acc_state ->
        mutation = UpdateBalanceAccountMutation.new(account_pk, balance)
        acc_state = Mutation.execute(mutation, acc_state)

        assert {:ok, Model.account_balance(index: ^account_pk, balance: ^balance)} =
                 State.get(acc_state, Model.AccountBalance, account_pk)

        assert {:ok, Model.balance_account(index: {^balance, ^account_pk})} =
                 State.get(acc_state, Model.BalanceAccount, {balance, account_pk})

        acc_state
      end)

    assert state
           |> Collection.stream(Model.BalanceAccount, :backward, {nil, nil}, nil)
           |> Enum.count() == 100

    assert state
           |> Collection.stream(Model.AccountBalance, :backward, {nil, nil}, nil)
           |> Enum.count() == 100

    {_, state} =
      Enum.reduce(account_pks, {0, state}, fn account_pk, {counter, state_acc} ->
        if rem(counter, 2) == 0 do
          account_pk
          |> UpdateBalanceAccountMutation.new(counter)
          |> Mutation.execute(state_acc)

          assert {:ok, Model.account_balance(index: ^account_pk, balance: ^counter)} =
                   State.get(state_acc, Model.AccountBalance, account_pk)

          assert {:ok, Model.balance_account(index: {^counter, ^account_pk})} =
                   State.get(state_acc, Model.BalanceAccount, {counter, account_pk})
        end

        {counter + 1, state_acc}
      end)

    balance_accounts =
      Collection.stream(state, Model.BalanceAccount, :backward, {nil, nil}, nil)

    assert Enum.count(balance_accounts) == 100

    account_balances =
      Collection.stream(state, Model.AccountBalance, :backward, {nil, nil}, nil)

    assert Enum.count(account_balances) == 100

    delete_mutation =
      DeleteKeysMutation.new(%{
        Model.AccountBalance => account_pks,
        Model.BalanceAccount =>
          Enum.map(balance_accounts, fn {balance, account_pk} ->
            {balance, account_pk}
          end)
      })

    Mutation.execute(delete_mutation, state)
  end
end
