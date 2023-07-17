defmodule AeMdw.Db.MemStoreTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Store

  require Model

  describe "when empty fallback" do
    test "it behaves like a key-value sorted store" do
      mem_store = MemStore.new(NullStore.new())

      mem_store2 =
        mem_store
        |> Store.put(Model.Block, Model.block(index: {4, 0}, hash: :val4))
        |> Store.put(Model.Block, Model.block(index: {1, 0}, hash: :val1))
        |> Store.put(Model.Block, Model.block(index: {3, 0}, hash: :old_val))
        |> Store.put(Model.Block, Model.block(index: {3, 0}, hash: :val3))
        |> Store.put(Model.Block, Model.block(index: {2, 0}, hash: :val1))
        |> Store.delete(Model.Block, {2, 0})

      assert 3 = Store.count_keys(mem_store2, Model.Block)

      assert {:ok, Model.block(index: {3, 0}, hash: :val3)} =
               Store.get(mem_store2, Model.Block, {3, 0})

      assert :not_found = Store.get(mem_store2, Model.Block, {2, 0})

      assert :none = Store.next(mem_store2, Model.Block, {4, 0})
      assert {:ok, {4, 0}} = Store.prev(mem_store2, Model.Block, nil)
      assert :none = Store.prev(mem_store2, Model.Block, {1, 0})
      assert {:ok, {1, 0}} = Store.prev(mem_store2, Model.Block, {3, 0})
    end
  end

  describe "when fallback" do
    test "it merges the results from both stores" do
      fallback_store = MemStore.new(NullStore.new())

      fallback_store2 =
        fallback_store
        |> Store.put(Model.Block, Model.block(index: {2, 0}, hash: :val2))
        |> Store.put(Model.Block, Model.block(index: {4, 0}, hash: :val4))
        |> Store.put(Model.Block, Model.block(index: {6, 0}, hash: :val6))

      mem_store = MemStore.new(fallback_store2)

      assert 3 = Store.count_keys(mem_store, Model.Block)

      mem_store2 =
        mem_store
        |> Store.put(Model.Block, Model.block(index: {3, 0}, hash: :val3))
        |> Store.put(Model.Block, Model.block(index: {5, 0}, hash: :val5))
        |> Store.put(Model.Block, Model.block(index: {7, 0}, hash: :val7))
        |> Store.delete(Model.Block, {5, 0})
        |> Store.delete(Model.Block, {4, 0})

      assert 4 = Store.count_keys(mem_store2, Model.Block)

      assert {:ok, Model.block(index: {3, 0}, hash: :val3)} =
               Store.get(mem_store2, Model.Block, {3, 0})

      assert {:ok, Model.block(index: {2, 0}, hash: :val2)} =
               Store.get(mem_store2, Model.Block, {2, 0})

      assert :not_found = Store.get(mem_store2, Model.Block, {4, 0})
      assert :not_found = Store.get(mem_store2, Model.Block, {5, 0})

      assert {:ok, {6, 0}} = Store.next(mem_store2, Model.Block, {3, 0})
      assert {:ok, {6, 0}} = Store.next(mem_store2, Model.Block, {4, 0})
      assert {:ok, {6, 0}} = Store.next(mem_store2, Model.Block, {5, 0})
      assert {:ok, {7, 0}} = Store.prev(mem_store2, Model.Block, nil)
      assert :none = Store.prev(mem_store2, Model.Block, {1, 0})
      assert :none = Store.prev(mem_store2, Model.Block, {2, 0})
      assert {:ok, {2, 0}} = Store.prev(mem_store2, Model.Block, {3, 0})
    end
  end
end
