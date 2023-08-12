defmodule AeMdw.Db.Sync.ObjectKeysTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.TxnDbStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Db.Sync.ObjectKeys

  require Model

  setup_all do
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

    on_exit(fn ->
      :ets.delete(:db_inactive_names, "name-i1")
      :ets.delete(:db_active_names, "name-a1")
      :ets.delete(:db_active_names, "name-a2")
      :ets.delete(:db_inactive_oracles, <<11::256>>)
      :ets.delete(:db_inactive_oracles, <<12::256>>)
      :ets.delete(:db_inactive_oracles, <<13::256>>)
      :ets.delete(:db_active_oracles, <<14::256>>)
      :ets.delete(:db_active_oracles, <<15::256>>)
      :ets.delete(:db_active_oracles, <<16::256>>)
      :ets.delete(:db_active_oracles, <<17::256>>)
    end)
  end

  test "returns sum counting commited and memory keys" do
    empty_mem_state = NullStore.new() |> MemStore.new() |> State.new()

    assert 1 == ObjectKeys.count_inactive_names(empty_mem_state)
    assert 2 == ObjectKeys.count_active_names(empty_mem_state)
    assert 3 == ObjectKeys.count_inactive_oracles(empty_mem_state)
    assert 4 == ObjectKeys.count_active_oracles(empty_mem_state)

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
      |> State.new()

    assert 1 + 1 == ObjectKeys.count_inactive_names(state)
    assert 2 + 1 == ObjectKeys.count_active_names(state)
    assert 3 + 1 == ObjectKeys.count_inactive_oracles(state)
    assert 4 + 1 == ObjectKeys.count_active_oracles(state)

    # cleanup
    :ets.delete(:db_inactive_names, "name-i11")
    :ets.delete(:db_active_names, "name-a11")
    :ets.delete(:db_inactive_oracles, <<21::256>>)
    :ets.delete(:db_active_oracles, <<24::256>>)
  end

  test "returns sum counting commited and db transaction keys" do
    empty_mem_state = NullStore.new() |> MemStore.new() |> State.new()

    assert 1 == ObjectKeys.count_inactive_names(empty_mem_state)
    assert 2 == ObjectKeys.count_active_names(empty_mem_state)
    assert 3 == ObjectKeys.count_inactive_oracles(empty_mem_state)
    assert 4 == ObjectKeys.count_active_oracles(empty_mem_state)

    TxnDbStore.transaction(fn store ->
      state =
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

      assert 1 + 1 == ObjectKeys.count_inactive_names(state)
      assert 2 + 1 == ObjectKeys.count_active_names(state)
      assert 3 + 1 == ObjectKeys.count_inactive_oracles(state)
      assert 4 + 1 == ObjectKeys.count_active_oracles(state)
    end)

    db_state = State.new()

    assert 1 + 1 == ObjectKeys.count_inactive_names(db_state)
    assert 2 + 1 == ObjectKeys.count_active_names(db_state)
    assert 3 + 1 == ObjectKeys.count_inactive_oracles(db_state)
    assert 4 + 1 == ObjectKeys.count_active_oracles(db_state)

    # cleanup
    :ets.delete(:db_inactive_names, "name-i12")
    :ets.delete(:db_active_names, "name-a12")
    :ets.delete(:db_inactive_oracles, <<22::256>>)
    :ets.delete(:db_active_oracles, <<25::256>>)
    State.delete(db_state, Model.InactiveName, "name-i12")
    State.delete(db_state, Model.ActiveName, "name-a12")
    State.delete(db_state, Model.InactiveOracle, <<22::256>>)
    State.delete(db_state, Model.ActiveOracle, <<25::256>>)
  end
end
