defmodule AeMdw.Migrations.RecountAex9HoldersTest do
  use ExUnit.Case, async: false

  alias AeMdw.Aex9
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Migrations.RecountAex9Holders
  alias AeMdw.Stats

  require Model

  # priv/migrations isn't compiled in the test env
  unless Code.ensure_loaded?(RecountAex9Holders) do
    Code.require_file("priv/migrations/20261104120000_recount_aex9_holders.ex")
  end

  test "sets each aex9 holders counter to the accounts with a positive balance" do
    drifted_pk = :crypto.strong_rand_bytes(32)
    uncounted_pk = :crypto.strong_rand_bytes(32)
    emptied_pk = :crypto.strong_rand_bytes(32)

    balances = [
      {drifted_pk, :crypto.strong_rand_bytes(32), 100},
      {drifted_pk, :crypto.strong_rand_bytes(32), 0},
      {drifted_pk, :crypto.strong_rand_bytes(32), -5},
      {drifted_pk, <<>>, nil},
      {uncounted_pk, :crypto.strong_rand_bytes(32), 1},
      {uncounted_pk, :crypto.strong_rand_bytes(32), 2}
    ]

    Enum.each(balances, fn {contract_pk, account_pk, amount} ->
      Database.dirty_write(
        Model.Aex9EventBalance,
        Model.aex9_event_balance(index: {contract_pk, account_pk}, amount: amount)
      )
    end)

    Enum.each([{drifted_pk, 7}, {emptied_pk, -1}], fn {contract_pk, count} ->
      Database.dirty_write(
        Model.Stat,
        Model.stat(index: Stats.aex9_holder_count_key(contract_pk), payload: count)
      )
    end)

    on_exit(fn ->
      Enum.each(balances, fn {contract_pk, account_pk, _amount} ->
        Database.dirty_delete(Model.Aex9EventBalance, {contract_pk, account_pk})
      end)

      Enum.each([drifted_pk, uncounted_pk, emptied_pk], fn contract_pk ->
        Database.dirty_delete(Model.Stat, Stats.aex9_holder_count_key(contract_pk))
      end)
    end)

    assert {:ok, updated_count} = RecountAex9Holders.run(State.new(), false)
    assert updated_count >= 3

    state = State.new()

    assert 1 == Stats.fetch_aex9_holders_count(state, drifted_pk)
    assert 2 == Stats.fetch_aex9_holders_count(state, uncounted_pk)
    assert 0 == Stats.fetch_aex9_holders_count(state, emptied_pk)

    assert {:ok, 0} = RecountAex9Holders.run(State.new(), false)
  end

  test "clears the invalid number of holders flags, keeping the other ones" do
    drifted_pk = :crypto.strong_rand_bytes(32)
    other_pk = :crypto.strong_rand_bytes(32)

    flags = [
      {drifted_pk, Aex9.invalid_number_of_holders_reason()},
      {other_pk, Aex9.invalid_holder_balance_reason()}
    ]

    Enum.each(flags, fn {contract_pk, reason} ->
      Database.dirty_write(
        Model.AexnInvalidContract,
        Model.aexn_invalid_contract(index: {:aex9, contract_pk}, reason: reason)
      )
    end)

    on_exit(fn ->
      Enum.each(flags, fn {contract_pk, _reason} ->
        Database.dirty_delete(Model.AexnInvalidContract, {:aex9, contract_pk})
      end)
    end)

    assert {:ok, updated_count} = RecountAex9Holders.run(State.new(), false)
    assert updated_count >= 1

    state = State.new()

    refute State.exists?(state, Model.AexnInvalidContract, {:aex9, drifted_pk})
    assert State.exists?(state, Model.AexnInvalidContract, {:aex9, other_pk})
  end
end
