defmodule AeMdw.Migrations.IndexAex9MintsAndBurnsByContractTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Migrations.IndexAex9MintsAndBurnsByContract

  require Model

  # priv/migrations isn't compiled in the test env
  unless Code.ensure_loaded?(IndexAex9MintsAndBurnsByContract) do
    Code.require_file("priv/migrations/20261020100000_index_aex9_mints_and_burns_by_contract.ex")
  end

  test "indexes mints and burns by contract, leaving transfers between accounts alone" do
    contract_pk = :crypto.strong_rand_bytes(32)
    account_pk = :crypto.strong_rand_bytes(32)
    other_pk = :crypto.strong_rand_bytes(32)
    create_txi = Enum.random(100_000_000..999_999_999)
    txi = create_txi + 1

    # a mint, a burn, a WAE-style withdrawal and a transfer between accounts
    transfer_keys = [
      {:aex9, contract_pk, txi, 0, account_pk, 1_000},
      {:aex9, account_pk, txi, 1, nil, 100},
      {:aex9, account_pk, txi, 2, contract_pk, 50},
      {:aex9, account_pk, txi, 3, other_pk, 10}
    ]

    field_key = {:contract_create_tx, nil, contract_pk, create_txi}
    Database.dirty_write(Model.Field, Model.field(index: field_key))

    Enum.each(transfer_keys, fn key ->
      Database.dirty_write(
        Model.AexnTransfer,
        Model.aexn_transfer(index: key, contract_pk: contract_pk)
      )
    end)

    from_keys = [
      {create_txi, contract_pk, txi, 0, account_pk, 1_000},
      {create_txi, account_pk, txi, 1, nil, 100},
      {create_txi, account_pk, txi, 2, contract_pk, 50}
    ]

    to_keys = [
      {create_txi, account_pk, txi, 0, contract_pk, 1_000},
      {create_txi, contract_pk, txi, 2, account_pk, 50}
    ]

    on_exit(fn ->
      Database.dirty_delete(Model.Field, field_key)
      Enum.each(transfer_keys, &Database.dirty_delete(Model.AexnTransfer, &1))
      Enum.each(from_keys, &Database.dirty_delete(Model.AexnContractFromTransfer, &1))
      Enum.each(to_keys, &Database.dirty_delete(Model.AexnContractToTransfer, &1))
    end)

    assert {:ok, count} = IndexAex9MintsAndBurnsByContract.run(State.new(), false)
    assert count >= length(from_keys) + length(to_keys)

    assert Enum.all?(from_keys, &Database.exists?(Model.AexnContractFromTransfer, &1))
    assert Enum.all?(to_keys, &Database.exists?(Model.AexnContractToTransfer, &1))

    refute Database.exists?(
             Model.AexnContractToTransfer,
             {create_txi, nil, txi, 1, account_pk, 100}
           )

    refute Database.exists?(
             Model.AexnContractFromTransfer,
             {create_txi, account_pk, txi, 3, other_pk, 10}
           )
  end
end
