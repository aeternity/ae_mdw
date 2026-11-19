defmodule AeMdw.Migrations.FixGenesisIntTransfersTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.IntTransfersMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  import Mock

  require Model

  @kb0 {0, -1}

  setup_all do
    migration = AeMdw.Migrations.FixGenesisIntTransfers

    # migrations are only compiled when applied, at startup unless they already were
    unless Code.ensure_loaded?(migration) do
      Code.require_file("priv/migrations/20261119120000_fix_genesis_int_transfers.ex")
    end

    {:ok, migration: migration}
  end

  setup do
    kb0 = Database.fetch(Model.Block, @kb0)
    accounts = Enum.map(1..3, fn i -> {:crypto.strong_rand_bytes(32), i * 1_000} end)

    on_exit(fn ->
      case kb0 do
        {:ok, block} -> Database.dirty_write(Model.Block, block)
        :not_found -> Database.dirty_delete(Model.Block, @kb0)
      end

      for {pk, _amount} <- accounts, kind <- ~w(accounts_genesis accounts_roma) do
        Database.dirty_delete(Model.IntTransferTx, {@kb0, kind, pk, -1})
        Database.dirty_delete(Model.KindIntTransferTx, {kind, @kb0, pk, -1})
        Database.dirty_delete(Model.TargetKindIntTransferTx, {pk, kind, @kb0, -1})
      end
    end)

    {:ok, accounts: accounts}
  end

  test "renames the accounts_genesis transfers, also when run again", %{
    migration: migration,
    accounts: accounts
  } do
    write_kb0()
    write_transfers("accounts_genesis", accounts)

    assert {:ok, 6} = run(migration, accounts)
    assert roma_rows(accounts) == genesis_rows(accounts)

    assert {:ok, 3} = run(migration, accounts)
    assert roma_rows(accounts) == genesis_rows(accounts)
  end

  test "drops the accounts_genesis transfers that are also stored as accounts_roma", %{
    migration: migration,
    accounts: accounts
  } do
    write_kb0()
    write_transfers("accounts_genesis", accounts)
    write_transfers("accounts_roma", accounts)

    assert {:ok, 6} = run(migration, accounts)
    assert roma_rows(accounts) == genesis_rows(accounts)
  end

  test "writes the accounts_roma transfers when height 0 is synced without them", %{
    migration: migration,
    accounts: accounts
  } do
    write_kb0()

    assert {:ok, 3} = run(migration, accounts)
    assert roma_rows(accounts) == genesis_rows(accounts)
  end

  test "writes no transfers when height 0 isn't synced yet", %{
    migration: migration,
    accounts: accounts
  } do
    Database.dirty_delete(Model.Block, @kb0)
    write_transfers("accounts_genesis", accounts)

    assert {:ok, 3} = run(migration, accounts)
    assert [] == genesis_rows(accounts)
  end

  defp run(migration, accounts) do
    with_mock :aec_fork_block_settings, [:passthrough], genesis_accounts: fn -> accounts end do
      migration.run(State.new(), false)
    end
  end

  defp write_kb0 do
    if not Database.exists?(Model.Block, @kb0) do
      Database.dirty_write(Model.Block, Model.block(index: @kb0, hash: <<0::256>>, tx_index: 0))
    end
  end

  defp write_transfers(kind, accounts) do
    transfers = Enum.map(accounts, fn {pk, amount} -> {kind, pk, amount} end)
    _state = State.commit_db(State.new(), [IntTransfersMutation.new(0, transfers)])
  end

  defp roma_rows(accounts) do
    accounts
    |> Enum.map(fn {pk, amount} -> {"accounts_roma", pk, amount} end)
    |> Enum.sort()
  end

  # rows of the given accounts at height 0, checking that all three tables agree
  defp genesis_rows(accounts) do
    pks = Enum.map(accounts, &elem(&1, 0))

    rows =
      for {@kb0, kind, pk, -1} = key <- Database.all_keys(Model.IntTransferTx), pk in pks do
        Model.int_transfer_tx(amount: amount) = Database.fetch!(Model.IntTransferTx, key)
        {kind, pk, amount}
      end

    kinds_pks = for {kind, pk, _amount} <- rows, do: {kind, pk}

    assert Enum.sort(kinds_pks) ==
             Enum.sort(
               for {kind, @kb0, pk, -1} <- Database.all_keys(Model.KindIntTransferTx),
                   pk in pks,
                   do: {kind, pk}
             )

    assert Enum.sort(kinds_pks) ==
             Enum.sort(
               for {pk, kind, @kb0, -1} <- Database.all_keys(Model.TargetKindIntTransferTx),
                   pk in pks,
                   do: {kind, pk}
             )

    Enum.sort(rows)
  end
end
