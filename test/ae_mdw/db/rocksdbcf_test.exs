defmodule AeMdw.Db.RocksDbCFTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.RocksDb

  import AeMdw.Db.ModelFixtures

  require Model

  defp setup_transaction(_ctx) do
    {:ok, txn} = RocksDb.transaction_new()

    {:ok, txn: txn}
  end

  describe "read_tx/1" do
    setup :setup_transaction

    test "reads a tx from transaction", %{txn: txn} do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(txn, Model.Tx, m_tx)
      assert {:ok, ^m_tx} = RocksDbCF.read_tx(txi)
    end

    test "reads a committed tx", %{txn: txn} do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(txn, Model.Tx, m_tx)
      assert :ok = RocksDb.transaction_commit(txn)
      assert {:ok, ^m_tx} = RocksDbCF.read_tx(txi)
    end
  end

  describe "read_block/1" do
    setup :setup_transaction

    test "read a block from transaction", %{txn: txn} do
      Model.block(index: key) = m_block = new_block()
      assert :ok = RocksDbCF.put(txn, Model.Block, m_block)
      assert {:ok, ^m_block} = RocksDbCF.read_block(key)
    end

    test "reads a committed block", %{txn: txn} do
      Model.block(index: key) = m_block = new_block()
      assert :ok = RocksDbCF.put(txn, Model.Block, m_block)
      assert :ok = RocksDb.transaction_commit(txn)
      assert {:ok, ^m_block} = RocksDbCF.read_block(key)
    end
  end

  describe "put/2" do
    setup :setup_transaction

    test "writes only to transaction", %{txn: txn} do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(txn, Model.Tx, m_tx)
      assert :not_found = RocksDbCF.fetch(Model.Tx, txi)
    end

    test "writes after commit", %{txn: txn} do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(txn, Model.Tx, m_tx)
      assert :not_found = RocksDbCF.fetch(Model.Tx, txi)
      assert :ok = RocksDb.transaction_commit(txn)
      assert {:ok, ^m_tx} = RocksDbCF.fetch(Model.Tx, txi)
    end
  end

  describe "dirty_delete/2" do
    test "dirty_delete directly a committed record" do
      key = {654_321, -1}
      m_block = Model.block(index: key)
      assert :ok = RocksDbCF.dirty_put(Model.Block, m_block)
      assert {:ok, ^m_block} = RocksDbCF.fetch(Model.Block, key)
      assert :ok = RocksDbCF.dirty_delete(Model.Block, key)
      assert :not_found = RocksDbCF.fetch(Model.Block, key)
    end
  end

  describe "count/1" do
    test "returns the count of writen records" do
      assert RocksDbCF.count(Model.Tx) < 50

      Enum.each(1..50, fn _i ->
        m_tx = Model.tx(index: new_txi())
        assert :ok = RocksDbCF.dirty_put(Model.Tx, m_tx)
      end)

      assert RocksDbCF.count(Model.Tx) >= 50
    end
  end

  describe "exists?/2" do
    setup :setup_transaction

    test "returns true when is commited", %{txn: txn} do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(txn, Model.Tx, m_tx)
      assert :ok = RocksDb.transaction_commit(txn)
      assert RocksDbCF.exists?(Model.Tx, txi)
    end

    test "returns false when is not commited", %{txn: txn} do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(txn, Model.Tx, m_tx)
      refute RocksDbCF.exists?(Model.Tx, txi)
    end
  end

  describe "first_key/1" do
    test "returns the first key when table is not empty" do
      assert :ok = RocksDbCF.dirty_put(Model.Tx, Model.tx(index: 0))
      assert {:ok, 0} = RocksDbCF.first_key(Model.Tx)
    end
  end

  describe "last_key/1" do
    test "returns the last key when table is not empty" do
      assert :ok = RocksDbCF.dirty_put(Model.Tx, Model.tx(index: new_txi()))
      assert {:ok, last_txi} = RocksDbCF.last_key(Model.Tx)
      assert {:ok, Model.tx(index: ^last_txi)} = RocksDbCF.fetch(Model.Tx, last_txi)
    end
  end

  describe "prev_key/2" do
    test "returns :not_found when there is no previous key" do
      assert :not_found = RocksDbCF.prev_key(Model.Tx, 0)
    end

    test "returns the previous key for integer" do
      assert :ok = RocksDbCF.dirty_put(Model.Tx, Model.tx(index: 0))
      assert :ok = RocksDbCF.dirty_put(Model.Tx, Model.tx(index: 1))
      assert {:ok, 0} = RocksDbCF.prev_key(Model.Tx, 1)
    end

    test "returns the previous key for tuple" do
      assert :ok = RocksDbCF.dirty_put(Model.Block, Model.block(index: {0, -1}))
      assert {:ok, {0, -1}} = RocksDbCF.prev_key(Model.Block, {0, nil})
    end
  end

  describe "next_key/2" do
    test "returns :not_found when there is no next key" do
      assert :not_found = RocksDbCF.next_key(Model.Tx, nil)
    end

    test "returns the next key for integer" do
      assert :ok = RocksDbCF.dirty_put(Model.Tx, Model.tx(index: 1))
      assert :ok = RocksDbCF.dirty_put(Model.Tx, Model.tx(index: 2))
      assert {:ok, 2} = RocksDbCF.next_key(Model.Tx, 1)
    end

    test "returns the next key for tuple" do
      assert :ok = RocksDbCF.dirty_put(Model.Block, Model.block(index: {0, -1}))
      assert :ok = RocksDbCF.dirty_put(Model.Block, Model.block(index: {1, -1}))
      assert {:ok, {1, -1}} = RocksDbCF.next_key(Model.Block, {0, -1})
      assert {:ok, {0, -1}} = RocksDbCF.next_key(Model.Block, {0, -2})
    end
  end

  describe "dirty_fetch/2" do
    setup :setup_transaction

    test "returns :not_found when key does not exist", %{txn: txn} do
      assert :not_found = RocksDbCF.dirty_fetch(txn, Model.Tx, :unknown)
    end

    test "returns the record from the transaction", %{txn: txn} do
      key = new_txi()

      m_tx =
        Model.tx(
          index: key,
          id: :crypto.strong_rand_bytes(32),
          block_index: {1234, 0},
          time: 5678
        )

      assert :ok = RocksDbCF.put(txn, Model.Tx, m_tx)
      assert {:ok, ^m_tx} = RocksDbCF.dirty_fetch(txn, Model.Tx, key)
    end

    test "returns the committed record of a key", %{txn: txn} do
      key = new_txi()

      m_tx =
        Model.tx(
          index: key,
          id: :crypto.strong_rand_bytes(32),
          block_index: {1234, 0},
          time: 5678
        )

      assert :ok = RocksDbCF.put(txn, Model.Tx, m_tx)
      assert :ok = RocksDb.transaction_commit(txn)
      {:ok, new_txn} = RocksDb.transaction_new()
      assert {:ok, ^m_tx} = RocksDbCF.dirty_fetch(new_txn, Model.Tx, key)
    end
  end

  describe "fetch/2" do
    setup :setup_transaction

    test "returns :not_found when key does not exist" do
      assert :not_found = RocksDbCF.fetch(Model.Tx, :unknown)
      assert :not_found = RocksDbCF.fetch(Model.Block, :unknown)
    end

    test "returns :not_found for a record only in the transaction", %{txn: txn} do
      txi = 1_234_567_890
      assert :ok = RocksDbCF.put(txn, Model.Tx, Model.tx(index: txi))
      assert :not_found = RocksDbCF.fetch(Model.Tx, txi)

      key = {7_654_321, -1}
      assert :ok = RocksDbCF.put(txn, Model.Block, Model.block(index: key))
      assert :not_found = RocksDbCF.fetch(Model.Block, key)
    end

    test "returns a committed tx", %{txn: txn} do
      key = new_txi()

      m_tx =
        Model.tx(
          index: key,
          id: :crypto.strong_rand_bytes(32),
          block_index: {1234, 0},
          time: 5678
        )

      assert :ok = RocksDbCF.put(txn, Model.Tx, m_tx)
      assert :ok = RocksDb.transaction_commit(txn)
      assert {:ok, ^m_tx} = RocksDbCF.fetch(Model.Tx, key)
    end

    test "returns a committed block", %{txn: txn} do
      key = {new_kbi(), -1}

      m_block =
        Model.block(
          index: key,
          tx_index: Enum.random(1..1_000_000),
          hash: :crypto.strong_rand_bytes(32)
        )

      assert :ok = RocksDbCF.put(txn, Model.Block, m_block)
      assert :ok = RocksDb.transaction_commit(txn)
      assert {:ok, ^m_block} = RocksDbCF.fetch(Model.Block, key)
    end
  end
end
