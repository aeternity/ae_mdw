defmodule AeMdw.Db.MemStoreTest do
  use ExUnit.Case

  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Store

  describe "when empty fallback" do
    test "it behaves like a key-value sorted store" do
      mem_store = MemStore.new(NullStore.new())

      mem_store2 =
        mem_store
        |> Store.put(:table, {:record, :key4, :val4})
        |> Store.put(:table, {:record, :key1, :val1})
        |> Store.put(:table, {:record, :key3, :old_val})
        |> Store.put(:table, {:record, :key3, :val3})
        |> Store.put(:table, {:record, :key2, :val1})
        |> Store.delete(:table, :key2)

      assert 3 = Store.count_keys(mem_store2, :table)

      assert {:ok, {:record, :key3, :val3}} = Store.get(mem_store2, :table, :key3)
      assert :not_found = Store.get(mem_store2, :table, :key2)

      assert :none = Store.next(mem_store2, :table, :key4)
      assert {:ok, :key4} = Store.prev(mem_store2, :table, nil)
      assert :none = Store.prev(mem_store2, :table, :key1)
      assert {:ok, :key1} = Store.prev(mem_store2, :table, :key3)
    end
  end

  describe "when fallback" do
    test "it merges the results from both stores" do
      fallback_store = MemStore.new(NullStore.new())

      fallback_store2 =
        fallback_store
        |> Store.put(:table, {:record, :key2, :val2})
        |> Store.put(:table, {:record, :key4, :val4})
        |> Store.put(:table, {:record, :key6, :val6})

      mem_store = MemStore.new(fallback_store2)

      mem_store2 =
        mem_store
        |> Store.put(:table, {:record, :key3, :val3})
        |> Store.put(:table, {:record, :key5, :val5})
        |> Store.put(:table, {:record, :key7, :val7})
        |> Store.delete(:table, :key5)
        |> Store.delete(:table, :key4)

      # store_keys = [:key2, :key3, :key6, :key7]

      assert 4 = Store.count_keys(mem_store2, :table)

      assert {:ok, {:record, :key3, :val3}} = Store.get(mem_store2, :table, :key3)
      assert {:ok, {:record, :key2, :val2}} = Store.get(mem_store2, :table, :key2)
      assert :not_found = Store.get(mem_store2, :table, :key4)
      assert :not_found = Store.get(mem_store2, :table, :key5)

      assert {:ok, :key6} = Store.next(mem_store2, :table, :key3)
      assert {:ok, :key6} = Store.next(mem_store2, :table, :key4)
      assert {:ok, :key6} = Store.next(mem_store2, :table, :key5)
      assert {:ok, :key7} = Store.prev(mem_store2, :table, nil)
      assert :none = Store.prev(mem_store2, :table, :key1)
      assert :none = Store.prev(mem_store2, :table, :key2)
      assert {:ok, :key2} = Store.prev(mem_store2, :table, :key3)
    end
  end
end
