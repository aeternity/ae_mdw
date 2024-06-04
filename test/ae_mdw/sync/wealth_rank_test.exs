defmodule AeMdw.Sync.WealthRankTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.WealthRank

  require Model

  describe "update/2" do
    test "inserts balance for new account" do
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(100_000_000..999_999_999)

      state = State.mem_state()

      state =
        WealthRank.update_balances(state, [{account_pk, amount}])

      assert {:ok, Model.balance_account(index: {^amount, ^account_pk})} =
               State.get(state, Model.BalanceAccount, {amount, account_pk})
    end

    test "inserts balance without duplicates" do
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      amount11 = Enum.random(100_000_000..999_999_999)
      amount12 = Enum.random(100_000_000..999_999_999)
      amount21 = Enum.random(100_000_000..999_999_999)

      state = State.mem_state()

      state =
        WealthRank.update_balances(state, [
          {account_pk1, amount11},
          {account_pk2, amount21}
        ])

      assert {:ok, Model.balance_account(index: {^amount11, ^account_pk1})} =
               State.get(state, Model.BalanceAccount, {amount11, account_pk1})

      assert {:ok, Model.balance_account(index: {^amount21, ^account_pk2})} =
               State.get(state, Model.BalanceAccount, {amount21, account_pk2})

      assert :not_found =
               State.get(state, Model.BalanceAccount, {amount12, account_pk1})

      state =
        WealthRank.update_balances(state, [{account_pk1, amount12}])

      assert :not_found =
               State.get(state, Model.BalanceAccount, {amount11, account_pk1})

      assert {:ok, Model.balance_account(index: {^amount12, ^account_pk1})} =
               State.get(state, Model.BalanceAccount, {amount12, account_pk1})

      assert {:ok, Model.balance_account(index: {^amount21, ^account_pk2})} =
               State.get(state, Model.BalanceAccount, {amount21, account_pk2})
    end
  end
end
