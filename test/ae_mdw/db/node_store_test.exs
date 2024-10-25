defmodule AeMdw.Db.NodeStoreTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.NodeStore
  alias AeMdw.Db.Store

  require Model

  @table Model.Mempool

  setup do
    # create a mnesia table
    table = :ets.new(:mempool, [:set, :named_table, :ordered_set])

    # insert some data
    true = :ets.insert(table, {1, {:val1, :val2}})
    true = :ets.insert(table, {2, {:val2, :val3}})
    true = :ets.insert(table, {3, {:val3, :val4}})
    true = :ets.insert(table, {4, {:val4, :val5}})
    true = :ets.insert(table, {5, {:val5, :val6}})
    true = :ets.insert(table, {6, {:val6, :val7}})
    true = :ets.insert(table, {7, {:val7, :val8}})

    %{table: table}
  end

  describe "when empty fallback" do
    test "it behaves like a key-value sorted store" do
      node_store = NodeStore.new()

      assert 7 = Store.count_keys(node_store, @table)

      assert {:ok, {:val1, :val2}} =
               Store.get(node_store, @table, 1)

      assert :not_found = Store.get(node_store, @table, 8)

      assert :none = Store.next(node_store, @table, 7)
      assert {:ok, 7} = Store.prev(node_store, @table, nil)
      assert :none = Store.prev(node_store, @table, 1)
      assert {:ok, 1} = Store.prev(node_store, @table, 2)
    end
  end
end
