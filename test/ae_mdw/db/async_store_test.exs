defmodule AeMdw.Db.AsyncStoreTest do
  use ExUnit.Case

  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Store

  describe "next/2" do
    test "it returns the next value" do
      store = AsyncStore.instance()

      store =
        store
        |> Store.put(:table, {:record, :key1, :val1})
        |> Store.put(:table, {:record, :key2, :val2})

      assert {:ok, :key1} = Store.next(store, :table, :key0)
      assert {:ok, :key2} = Store.next(store, :table, :key1)
      assert :none = Store.next(store, :table, :key2)
    end

    test "when other tables present, it doesn't return values from them" do
      store = AsyncStore.instance()

      store =
        store
        |> Store.put(:table1, {:record, :key1, :val1})
        |> Store.put(:table1, {:record, :key2, :val2})
        |> Store.put(:table2, {:record, :key3, :val3})

      assert :none = Store.next(store, :table1, :key2)
    end
  end
end
