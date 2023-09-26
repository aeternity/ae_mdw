defmodule AeMdw.Db.Sync.ObjectKeysTest do
  use ExUnit.Case, async: false

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.TxnDbStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Db.Sync.ObjectKeys

  require Model

  setup do
    # cleanup
    :ets.delete_all_objects(:db_active_names)
    :ets.delete_all_objects(:db_inactive_names)
    :ets.delete_all_objects(:db_active_oracles)
    :ets.delete_all_objects(:db_inactive_oracles)
    :ets.delete_all_objects(:db_contracts)

    txn_state = State.new(%TxnDbStore{})
    ObjectKeys.put_inactive_name(txn_state, "name-i1")
    ObjectKeys.put_active_name(txn_state, "name-a1")
    ObjectKeys.put_active_name(txn_state, "name-a2")
    ObjectKeys.put_inactive_oracle(txn_state, <<11::256>>)
    ObjectKeys.put_inactive_oracle(txn_state, <<12::256>>)
    ObjectKeys.put_inactive_oracle(txn_state, <<13::256>>)
    ObjectKeys.put_active_oracle(txn_state, <<14::256>>)
    ObjectKeys.put_active_oracle(txn_state, <<15::256>>)
    ObjectKeys.put_active_oracle(txn_state, <<16::256>>)
    ObjectKeys.put_active_oracle(txn_state, <<17::256>>)
    ObjectKeys.put_contract(txn_state, <<18::256>>)
    ObjectKeys.put_contract(txn_state, <<19::256>>)
    ObjectKeys.put_contract(txn_state, <<20::256>>)
  end

  test "returns sum counting commited and memory keys" do
    empty_mem_state = NullStore.new() |> MemStore.new() |> State.new()

    assert 1 == ObjectKeys.count_inactive_names(empty_mem_state)
    assert 2 == ObjectKeys.count_active_names(empty_mem_state)
    assert 3 == ObjectKeys.count_inactive_oracles(empty_mem_state)
    assert 4 == ObjectKeys.count_active_oracles(empty_mem_state)
    assert 3 == ObjectKeys.count_contracts(empty_mem_state)

    fallback_store =
      NullStore.new()
      |> MemStore.new()
      |> Store.put(Model.ActiveName, Model.name(index: "ignored1"))
      |> Store.put(Model.InactiveName, Model.name(index: "ignored2"))
      |> Store.put(Model.ActiveOracle, Model.oracle(index: "ignored3"))
      |> Store.put(Model.InactiveOracle, Model.oracle(index: "ignored4"))

    state =
      fallback_store
      |> MemStore.new()
      |> Store.put(Model.InactiveName, Model.name(index: "name-i1"))
      |> Store.put(Model.InactiveName, Model.name(index: "name-i11"))
      |> Store.put(Model.ActiveName, Model.name(index: "name-a1"))
      |> Store.put(Model.ActiveName, Model.name(index: "name-a11"))
      |> Store.put(Model.InactiveOracle, Model.oracle(index: <<11::256>>))
      |> Store.put(Model.InactiveOracle, Model.oracle(index: <<21::256>>))
      |> Store.put(Model.ActiveOracle, Model.oracle(index: <<14::256>>))
      |> Store.put(Model.ActiveOracle, Model.oracle(index: <<24::256>>))
      |> Store.put(Model.Origin, Model.origin(index: {:contract_create_tx, <<18::256>>, 1_001}))
      |> Store.put(Model.Origin, Model.origin(index: {:contract_create_tx, <<28::256>>, 1_011}))
      |> Store.put(Model.Origin, Model.origin(index: {:contract_call_tx, <<19::256>>, 1_002}))
      |> Store.put(Model.Origin, Model.origin(index: {:contract_call_tx, <<29::256>>, 1_012}))
      |> Store.put(Model.Origin, Model.origin(index: {:ga_attach_tx, <<20::256>>, 1_003}))
      |> Store.put(Model.Origin, Model.origin(index: {:ga_attach_tx, <<30::256>>, 1_013}))
      |> State.new()

    assert 1 + 1 == ObjectKeys.count_inactive_names(state)
    assert 2 + 1 == ObjectKeys.count_active_names(state)
    assert 3 + 1 == ObjectKeys.count_inactive_oracles(state)
    assert 4 + 1 == ObjectKeys.count_active_oracles(state)
    assert 3 + 3 == ObjectKeys.count_contracts(state)
  end

  test "returns sum counting commited and db transaction keys" do
    empty_mem_state = NullStore.new() |> MemStore.new() |> State.new()

    assert 1 == ObjectKeys.count_inactive_names(empty_mem_state)
    assert 2 == ObjectKeys.count_active_names(empty_mem_state)
    assert 3 == ObjectKeys.count_inactive_oracles(empty_mem_state)
    assert 4 == ObjectKeys.count_active_oracles(empty_mem_state)
    assert 3 == ObjectKeys.count_contracts(empty_mem_state)

    TxnDbStore.transaction(fn store ->
      txn_state =
        store
        |> State.new()
        |> State.put(Model.InactiveName, Model.name(index: "name-i1"))
        |> State.put(Model.InactiveName, Model.name(index: "name-i12"))
        |> State.put(Model.ActiveName, Model.name(index: "name-a1"))
        |> State.put(Model.ActiveName, Model.name(index: "name-a12"))
        |> State.put(Model.InactiveOracle, Model.oracle(index: <<11::256>>))
        |> State.put(Model.InactiveOracle, Model.oracle(index: <<22::256>>))
        |> State.put(Model.ActiveOracle, Model.oracle(index: <<14::256>>))
        |> State.put(Model.ActiveOracle, Model.oracle(index: <<25::256>>))
        |> State.put(Model.Origin, Model.origin(index: {:contract_create_tx, <<18::256>>, 1_001}))
        |> State.put(Model.Origin, Model.origin(index: {:contract_create_tx, <<28::256>>, 1_011}))
        |> State.put(Model.Origin, Model.origin(index: {:contract_call_tx, <<19::256>>, 1_002}))
        |> State.put(Model.Origin, Model.origin(index: {:contract_call_tx, <<29::256>>, 1_012}))
        |> State.put(Model.Origin, Model.origin(index: {:ga_attach_tx, <<20::256>>, 1_003}))
        |> State.put(Model.Origin, Model.origin(index: {:ga_attach_tx, <<30::256>>, 1_013}))

      # counts only on memory
      assert 1 == ObjectKeys.count_inactive_names(txn_state)
      assert 2 == ObjectKeys.count_active_names(txn_state)
      assert 3 == ObjectKeys.count_inactive_oracles(txn_state)
      assert 4 == ObjectKeys.count_active_oracles(txn_state)
      assert 3 == ObjectKeys.count_contracts(empty_mem_state)

      ObjectKeys.put_inactive_name(txn_state, "name-i12")
      ObjectKeys.put_active_name(txn_state, "name-a12")
      ObjectKeys.put_inactive_oracle(txn_state, <<22::256>>)
      ObjectKeys.put_active_oracle(txn_state, <<25::256>>)
      ObjectKeys.put_contract(txn_state, <<28::256>>)
      ObjectKeys.put_contract(txn_state, <<29::256>>)
      ObjectKeys.put_contract(txn_state, <<30::256>>)
    end)

    db_state = State.new()

    # counts cached + on memory
    assert 1 + 1 == ObjectKeys.count_inactive_names(db_state)
    assert 2 + 1 == ObjectKeys.count_active_names(db_state)
    assert 3 + 1 == ObjectKeys.count_inactive_oracles(db_state)
    assert 4 + 1 == ObjectKeys.count_active_oracles(db_state)
    assert 3 + 3 == ObjectKeys.count_contracts(db_state)

    # cleanup
    State.delete(db_state, Model.InactiveName, "name-i12")
    State.delete(db_state, Model.ActiveName, "name-a12")
    State.delete(db_state, Model.InactiveOracle, <<22::256>>)
    State.delete(db_state, Model.ActiveOracle, <<25::256>>)
    State.delete(db_state, Model.Origin, {:contract_create_tx, <<28::256>>, 1_011})
    State.delete(db_state, Model.Origin, {:contract_call_tx, <<29::256>>, 1_012})
    State.delete(db_state, Model.Origin, {:ga_attach_tx, <<30::256>>, 1_013})
  end

  test "count performs better and stream counting" do
    # setup
    TxnDbStore.transaction(fn store ->
      Enum.reduce(1_001..11_001, State.new(store), fn i, acc ->
        pubkey = <<i::256>>
        ObjectKeys.put_contract(acc, pubkey)
        State.put(acc, Model.Origin, Model.origin(index: {:contract_create_tx, pubkey, i}))
      end)
    end)

    {time1, _val} =
      :timer.tc(fn ->
        State.new() |> Collection.stream(Model.Origin, nil) |> Enum.count()
      end)

    {time2, _val} =
      :timer.tc(fn ->
        ObjectKeys.count_contracts(State.new())
      end)

    assert div(time1, 1_000) > 200
    assert div(time1, time2) > 100

    # cleanup
    TxnDbStore.transaction(fn store ->
      Enum.reduce(1_001..11_001, State.new(store), fn i, acc ->
        pubkey = <<i::256>>
        :ets.delete(:db_contracts, pubkey)
        State.delete(acc, Model.Origin, {:contract_create_tx, pubkey, i})
      end)
    end)
  end
end
