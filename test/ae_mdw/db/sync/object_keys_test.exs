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

  @tables [Model.ActiveName, Model.InactiveName, Model.ActiveOracle, Model.InactiveOracle]

  describe "put/3 and delete/3" do
    test "count only keys that are added or removed" do
      state =
        empty_mem_state()
        |> ObjectKeys.put(Model.ActiveName, Model.name(index: "a1.chain"))
        |> ObjectKeys.put(Model.ActiveName, Model.name(index: "a2.chain"))
        |> ObjectKeys.put(Model.ActiveName, Model.name(index: "a2.chain", owner: <<1::256>>))
        |> ObjectKeys.put(Model.InactiveOracle, Model.oracle(index: <<1::256>>))

      assert %{active_names: 2, inactive_names: 0, active_oracles: 0, inactive_oracles: 1} =
               counts(state)

      state =
        state
        |> ObjectKeys.delete(Model.ActiveName, "a1.chain")
        |> ObjectKeys.delete(Model.ActiveName, "a1.chain")
        |> ObjectKeys.delete(Model.InactiveName, "missing.chain")
        |> ObjectKeys.delete(Model.InactiveOracle, <<1::256>>)

      assert %{active_names: 1, inactive_names: 0, active_oracles: 0, inactive_oracles: 0} =
               counts(state)

      assert {:ok, Model.name(owner: <<1::256>>)} =
               State.get(state, Model.ActiveName, "a2.chain")
    end

    test "count on top of the fallback store's keys" do
      fallback_state =
        empty_mem_state()
        |> ObjectKeys.put(Model.ActiveName, Model.name(index: "a1.chain"))
        |> ObjectKeys.put(Model.ActiveName, Model.name(index: "a2.chain"))

      state =
        fallback_state
        |> state_store()
        |> MemStore.new()
        |> State.new()
        |> ObjectKeys.delete(Model.ActiveName, "a1.chain")
        |> ObjectKeys.put(Model.InactiveName, Model.name(index: "a1.chain"))

      assert %{active_names: 1, inactive_names: 1} = counts(state)
      assert %{active_names: 2, inactive_names: 0} = counts(fallback_state)
    end

    test "count inside a db transaction" do
      oracle_pk = <<901::256>>
      # test_data.db persists between local runs
      remove_oracle = fn -> ObjectKeys.delete(State.new(), Model.ActiveOracle, oracle_pk) end
      remove_oracle.()
      on_exit(remove_oracle)

      before = ObjectKeys.count(State.new(), Model.ActiveOracle)

      TxnDbStore.transaction(fn store ->
        txn_state =
          store
          |> State.new()
          |> ObjectKeys.put(Model.ActiveOracle, Model.oracle(index: oracle_pk))

        assert before + 1 == ObjectKeys.count(txn_state, Model.ActiveOracle)
      end)

      assert before + 1 == ObjectKeys.count(State.new(), Model.ActiveOracle)

      TxnDbStore.transaction(fn store ->
        store
        |> State.new()
        |> ObjectKeys.delete(Model.ActiveOracle, oracle_pk)
      end)

      assert before == ObjectKeys.count(State.new(), Model.ActiveOracle)
    end
  end

  describe "recount_if_stale/1" do
    test "recounts unless the counts were kept up to the synced generation" do
      state =
        empty_mem_state()
        |> State.put(Model.DeltaStat, Model.delta_stat(index: 10))
        |> State.put(Model.Tx, Model.tx(index: 99))
        |> State.put(Model.ActiveName, Model.name(index: "a1.chain"))
        |> State.put(Model.ActiveName, Model.name(index: "a2.chain"))
        |> State.put(Model.InactiveOracle, Model.oracle(index: <<1::256>>))
        |> ObjectKeys.recount_if_stale()

      assert %{active_names: 2, inactive_names: 0, active_oracles: 0, inactive_oracles: 1} =
               counts(state)

      state =
        state
        |> ObjectKeys.put_counted_at(10, 100)
        |> State.put(Model.ActiveName, Model.name(index: "a3.chain"))
        |> ObjectKeys.recount_if_stale()

      assert %{active_names: 2} = counts(state)

      # an older version synced generations without txs, e.g. with only expirations
      state =
        state
        |> State.put(Model.DeltaStat, Model.delta_stat(index: 11))
        |> ObjectKeys.recount_if_stale()

      assert %{active_names: 3} = counts(state)

      state =
        state
        |> State.put(Model.ActiveName, Model.name(index: "a4.chain"))
        |> State.put(Model.Tx, Model.tx(index: 100))
        |> ObjectKeys.recount_if_stale()

      assert %{active_names: 4} = counts(state)
    end
  end

  describe "count_contracts/1" do
    setup do
      State.put(State.new(), Model.TotalStat, Model.total_stat(index: 0, contracts: 3))

      on_exit(fn ->
        State.delete(State.new(), Model.TotalStat, 0)
      end)

      :ok
    end

    test "returns sum counting commited and memory keys" do
      assert 3 == ObjectKeys.count_contracts(empty_mem_state())

      state =
        NullStore.new()
        |> MemStore.new()
        |> MemStore.new()
        |> Store.put(Model.Origin, Model.origin(index: {:contract_create_tx, <<18::256>>, 1_001}))
        |> Store.put(Model.Origin, Model.origin(index: {:contract_call_tx, <<19::256>>, 1_002}))
        |> Store.put(Model.Origin, Model.origin(index: {:ga_attach_tx, <<20::256>>, 1_003}))
        |> State.new()

      assert 3 + 3 == ObjectKeys.count_contracts(state)
    end

    test "count performs better than stream counting" do
      # setup
      TxnDbStore.transaction(fn store ->
        Enum.reduce(1_001..11_001, State.new(store), fn i, acc ->
          State.put(acc, Model.Origin, Model.origin(index: {:contract_create_tx, <<i::256>>, i}))
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

      assert div(time1, time2) > 100

      # cleanup
      TxnDbStore.transaction(fn store ->
        Enum.reduce(1_001..11_001, State.new(store), fn i, acc ->
          State.delete(acc, Model.Origin, {:contract_create_tx, <<i::256>>, i})
        end)
      end)
    end
  end

  defp empty_mem_state, do: NullStore.new() |> MemStore.new() |> State.new()

  defp state_store(%State{store: store}), do: store

  defp counts(state) do
    [active_names, inactive_names, active_oracles, inactive_oracles] =
      Enum.map(@tables, &ObjectKeys.count(state, &1))

    %{
      active_names: active_names,
      inactive_names: inactive_names,
      active_oracles: active_oracles,
      inactive_oracles: inactive_oracles
    }
  end
end
