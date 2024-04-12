defmodule AeMdw.Sync.AsyncTasks.WealthRankTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.WealthRank

  require Model

  describe "update/2" do
    test "inserts balance for new account" do
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(100_000_000..999_999_999)

      table = :insert_balance_for_new_account
      AsyncStore.init(table)
      async_store = AsyncStore.instance(table)

      assert :ok = WealthRank.update_balances(async_store, [{account_pk, amount}])

      assert {:ok, Model.balance_account(index: {^amount, ^account_pk})} =
               AsyncStore.get(async_store, Model.BalanceAccount, {amount, account_pk})
    end

    test "inserts balance without duplicates" do
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      amount11 = Enum.random(100_000_000..999_999_999)
      amount12 = Enum.random(100_000_000..999_999_999)
      amount21 = Enum.random(100_000_000..999_999_999)

      table = :insert_balance_without_duplicates

      AsyncStore.init(table)
      async_store = AsyncStore.instance(table)

      assert :ok =
               WealthRank.update_balances(async_store, [
                 {account_pk1, amount11},
                 {account_pk2, amount21}
               ])

      assert {:ok, Model.balance_account(index: {^amount11, ^account_pk1})} =
               AsyncStore.get(async_store, Model.BalanceAccount, {amount11, account_pk1})

      assert {:ok, Model.balance_account(index: {^amount21, ^account_pk2})} =
               AsyncStore.get(async_store, Model.BalanceAccount, {amount21, account_pk2})

      assert :not_found =
               AsyncStore.get(async_store, Model.BalanceAccount, {amount12, account_pk1})

      assert :ok = WealthRank.update_balances(async_store, [{account_pk1, amount12}])

      assert :not_found =
               AsyncStore.get(async_store, Model.BalanceAccount, {amount11, account_pk1})

      assert {:ok, Model.balance_account(index: {^amount12, ^account_pk1})} =
               AsyncStore.get(async_store, Model.BalanceAccount, {amount12, account_pk1})

      assert {:ok, Model.balance_account(index: {^amount21, ^account_pk2})} =
               AsyncStore.get(async_store, Model.BalanceAccount, {amount21, account_pk2})
    end
  end
end
