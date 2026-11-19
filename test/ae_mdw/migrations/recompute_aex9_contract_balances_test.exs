defmodule AeMdw.Migrations.RecomputeAex9ContractBalancesTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Migrations.RecomputeAex9ContractBalances

  require Model

  # priv/migrations isn't compiled in the test env
  unless Code.ensure_loaded?(RecomputeAex9ContractBalances) do
    Code.require_file("priv/migrations/20261119140000_recompute_aex9_contract_balances.ex")
  end

  test "sets each aex9 contract total to the sum of its balances" do
    doubled_pk = :crypto.strong_rand_bytes(32)
    halved_pk = :crypto.strong_rand_bytes(32)
    emptied_pk = :crypto.strong_rand_bytes(32)
    untotaled_pk = :crypto.strong_rand_bytes(32)
    exact_pk = :crypto.strong_rand_bytes(32)
    zero_pk = :crypto.strong_rand_bytes(32)

    balances = [
      {doubled_pk, :crypto.strong_rand_bytes(32), 100},
      {doubled_pk, :crypto.strong_rand_bytes(32), 50},
      {halved_pk, :crypto.strong_rand_bytes(32), 2_000},
      {untotaled_pk, :crypto.strong_rand_bytes(32), 7},
      {exact_pk, :crypto.strong_rand_bytes(32), 10},
      {exact_pk, :crypto.strong_rand_bytes(32), -3},
      {exact_pk, :crypto.strong_rand_bytes(32), 0},
      {exact_pk, <<>>, nil},
      {zero_pk, :crypto.strong_rand_bytes(32), 0}
    ]

    totals = [{doubled_pk, 250}, {halved_pk, 0}, {emptied_pk, -1_000}, {exact_pk, 7}]

    Enum.each(balances, fn {contract_pk, account_pk, amount} ->
      Database.dirty_write(
        Model.Aex9EventBalance,
        Model.aex9_event_balance(index: {contract_pk, account_pk}, amount: amount)
      )
    end)

    Enum.each(totals, fn {contract_pk, amount} ->
      Database.dirty_write(
        Model.Aex9ContractBalance,
        Model.aex9_contract_balance(index: contract_pk, amount: amount)
      )
    end)

    on_exit(fn ->
      Enum.each(balances, fn {contract_pk, account_pk, _amount} ->
        Database.dirty_delete(Model.Aex9EventBalance, {contract_pk, account_pk})
      end)

      Enum.each([doubled_pk, halved_pk, emptied_pk, untotaled_pk, exact_pk, zero_pk], fn pk ->
        Database.dirty_delete(Model.Aex9ContractBalance, pk)
      end)
    end)

    assert {:ok, updated_count} = RecomputeAex9ContractBalances.run(State.new(), false)
    assert updated_count >= 4

    state = State.new()

    assert 150 == total(state, doubled_pk)
    assert 2_000 == total(state, halved_pk)
    assert 0 == total(state, emptied_pk)
    assert 7 == total(state, untotaled_pk)
    assert 7 == total(state, exact_pk)
    refute State.exists?(state, Model.Aex9ContractBalance, zero_pk)

    assert {:ok, 0} = RecomputeAex9ContractBalances.run(State.new(), false)
  end

  defp total(state, contract_pk) do
    Model.aex9_contract_balance(amount: amount) =
      State.fetch!(state, Model.Aex9ContractBalance, contract_pk)

    amount
  end
end
