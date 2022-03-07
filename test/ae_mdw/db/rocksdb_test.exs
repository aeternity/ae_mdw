defmodule AeMdw.Db.RocksDbTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDb

  import AeMdw.Db.ModelFixtures, only: [new_block: 0, new_kbi: 0]

  describe "dirty operations/3" do
    test "writes a key-value only to the transaction" do
      {:ok, txn} = RocksDb.transaction_new()
      key = :erlang.term_to_binary({new_kbi(), -1})
      value = new_block() |> :erlang.term_to_binary()

      assert :ok = RocksDb.put(txn, Model.Block, key, value)
      assert {:ok, ^value} = RocksDb.dirty_get(txn, Model.Block, key)
      assert :not_found = RocksDb.get(Model.Block, key)
    end

    test "persists a key-value without transaction" do
      key = :erlang.term_to_binary({new_kbi(), -1})
      value = new_block() |> :erlang.term_to_binary()

      assert :ok = RocksDb.dirty_put(Model.Block, key, value)
      assert {:ok, ^value} = RocksDb.get(Model.Block, key)
    end

    test "delete a key-value from the transaction" do
      {:ok, txn} = RocksDb.transaction_new()
      key = :erlang.term_to_binary({new_kbi(), -1})
      value = new_block() |> :erlang.term_to_binary()

      assert :ok = RocksDb.put(txn, Model.Block, key, value)
      assert :ok = RocksDb.delete(txn, Model.Block, key)
      assert :not_found = RocksDb.dirty_get(txn, Model.Block, key)
    end
  end

  describe "commit/4 and get/2" do
    test "persists a transaction with a single change" do
      {:ok, txn} = RocksDb.transaction_new()
      key = :erlang.term_to_binary({new_kbi(), -1})
      value = new_block() |> :erlang.term_to_binary()

      assert :ok = RocksDb.put(txn, Model.Block, key, value)
      RocksDb.transaction_commit(txn)
      assert {:ok, ^value} = RocksDb.get(Model.Block, key)
    end

    test "persists a transaction with a multiple changes" do
      {:ok, txn} = RocksDb.transaction_new()

      kv_list =
        Enum.map(1..100, fn _i ->
          key = :erlang.term_to_binary({new_kbi(), -1})
          value = new_block() |> :erlang.term_to_binary()

          assert :ok = RocksDb.put(txn, Model.Block, key, value)
          {key, value}
        end)

      RocksDb.transaction_commit(txn)

      Enum.each(kv_list, fn {key, value} ->
        assert {:ok, ^value} = RocksDb.get(Model.Block, key)
      end)
    end
  end
end
