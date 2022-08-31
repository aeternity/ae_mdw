defmodule AeMdw.Db.RocksDbTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDb

  import AeMdw.Db.ModelFixtures, only: [new_block: 0, new_kbi: 0]

  require Model

  describe "dirty operations/3" do
    test "writes a key-value only to the transaction" do
      {:ok, txn} = RocksDb.transaction_new()
      key = :erlang.term_to_binary({new_kbi(), -1})
      value = new_block() |> :erlang.term_to_binary()

      assert :ok = RocksDb.put(txn, Model.Block, key, value)
      assert {:ok, ^value} = RocksDb.dirty_get(txn, Model.Block, key)
      assert :not_found = RocksDb.get(Model.Block, key)
    end

    test "persists a key-value without a transaction" do
      key = :erlang.term_to_binary({new_kbi(), -1})
      value = new_block() |> :erlang.term_to_binary()

      assert :ok = RocksDb.dirty_put(Model.Block, key, value)
      assert {:ok, ^value} = RocksDb.get(Model.Block, key)
    end

    test "deletes multiple key-values without a transaction (A)" do
      Enum.each(1..10_000, fn _i ->
        m_block = Model.block(index: index) = new_block()
        key = :erlang.term_to_binary(index)
        value = :erlang.term_to_binary(m_block)

        assert :ok = RocksDb.dirty_put(Model.Block, key, value)
        assert :ok = RocksDb.dirty_delete(Model.Block, key)
        assert :not_found = RocksDb.get(Model.Block, key)
      end)
    end

    test "deletes multiple key-values without a transaction (B)" do
      1..10_000
      |> Enum.map(fn _i ->
        m_block = Model.block(index: index) = new_block()
        key = :erlang.term_to_binary(index)
        value = :erlang.term_to_binary(m_block)

        assert :ok = RocksDb.dirty_put(Model.Block, key, value)
        key
      end)
      |> Enum.each(fn key ->
        assert :ok = RocksDb.dirty_delete(Model.Block, key)
        assert :not_found = RocksDb.get(Model.Block, key)
      end)
    end

    test "deletes multiple key-values without a transaction (C)" do
      {:ok, txn} = RocksDb.transaction_new()

      keys =
        Enum.map(1..10_000, fn _i ->
          m_block = Model.block(index: index) = new_block()
          key = :erlang.term_to_binary(index)
          value = :erlang.term_to_binary(m_block)

          assert :ok = RocksDb.put(txn, Model.Block, key, value)
          key
        end)

      :ok = RocksDb.transaction_commit(txn)

      Enum.each(keys, fn key ->
        assert :ok = RocksDb.dirty_delete(Model.Block, key)
        assert :not_found = RocksDb.get(Model.Block, key)
      end)
    end

    test "deletes multiple key-values without a transaction (D)" do
      {:ok, txn} = RocksDb.transaction_new()

      keys =
        Enum.map(1..10_000, fn _i ->
          index = {System.system_time(), :update_aex9_state}

          m_task =
            Model.async_task(
              index: index,
              args: [:crypto.strong_rand_bytes(32)],
              extra_args: [{1, 0}, 1]
            )

          key = :erlang.term_to_binary(index)
          value = :erlang.term_to_binary(m_task)

          assert :ok = RocksDb.put(txn, Model.AsyncTask, key, value)
          key
        end)

      :ok = RocksDb.transaction_commit(txn)

      Enum.each(keys, fn key ->
        assert :ok = RocksDb.dirty_delete(Model.AsyncTask, key)
        assert :not_found = RocksDb.get(Model.AsyncTask, key)
      end)
    end
  end

  describe "delete/3" do
    test "delete a key-value from the transaction" do
      {:ok, txn} = RocksDb.transaction_new()
      key = :erlang.term_to_binary({new_kbi(), -1})
      value = new_block() |> :erlang.term_to_binary()

      assert :ok = RocksDb.put(txn, Model.Block, key, value)
      assert :ok = RocksDb.delete(txn, Model.Block, key)
      assert :not_found = RocksDb.dirty_get(txn, Model.Block, key)
    end

    test "it deletes a key-value not from the transaction" do
      key = :erlang.term_to_binary({new_kbi(), -1})
      value = new_block() |> :erlang.term_to_binary()

      assert :ok = RocksDb.dirty_put(Model.Block, key, value)

      {:ok, txn} = RocksDb.transaction_new()
      assert :ok = RocksDb.delete(txn, Model.Block, key)
      assert :not_found = RocksDb.dirty_get(txn, Model.Block, key)
      :ok = RocksDb.transaction_commit(txn)
    end

    test "it doesn't fail when deleting a non-existent key" do
      key = "non-existent-key"

      {:ok, txn} = RocksDb.transaction_new()
      assert :ok = RocksDb.delete(txn, Model.Block, key)
      :ok = RocksDb.transaction_commit(txn)
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
