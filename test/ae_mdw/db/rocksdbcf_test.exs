defmodule AeMdw.Db.RocksDbCFTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.RocksDb

  require Model

  describe "read_tx/1" do
    test "reads tx from transaction" do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      assert {:ok, ^m_tx} = RocksDbCF.read_tx(txi)
    end

    test "reads committed tx" do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      RocksDb.commit()
      assert {:ok, ^m_tx} = RocksDbCF.read_tx(txi)
    end
  end

  describe "put/2" do
    test "writes only to transaction" do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      assert :not_found = RocksDbCF.fetch(Model.Tx, txi)
    end

    test "writes after commit" do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      assert :not_found = RocksDbCF.fetch(Model.Tx, txi)
      RocksDb.commit()
      assert {:ok, ^m_tx} = RocksDbCF.fetch(Model.Tx, txi)
    end
  end

  describe "delete/2" do
    test "changes transaction" do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      assert {:ok, m_tx} = RocksDbCF.dirty_fetch(Model.Tx, txi)
      assert :ok = RocksDbCF.delete(Model.Tx, txi)
      assert :not_found = RocksDbCF.fetch(Model.Tx, txi)
    end

    test "deletes committed tx" do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      RocksDb.commit()
      assert {:ok, ^m_tx} = RocksDbCF.fetch(Model.Tx, txi)
      assert :ok = RocksDbCF.delete(Model.Tx, txi)
      assert :not_found = RocksDbCF.fetch(Model.Tx, txi)
    end
  end

  describe "exists?/2" do
    test "returns true when is commited" do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      RocksDb.commit()
      assert RocksDbCF.exists?(Model.Tx, txi)
    end

    test "returns false when is not commited" do
      txi = new_txi()
      m_tx = Model.tx(index: txi)
      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      refute RocksDbCF.exists?(Model.Tx, txi)
    end
  end

  describe "first_key/1" do
    test "returns the first key when table is not empty" do
      assert :ok = RocksDbCF.put(Model.Tx, Model.tx(index: new_txi()))
      RocksDb.commit()
      assert {:ok, 0} = RocksDbCF.first_key(Model.Tx)
    end
  end

  describe "last_key/1" do
    test "returns the last key when table is not empty" do
      assert :ok = RocksDbCF.put(Model.Tx, Model.tx(index: new_txi()))
      RocksDb.commit()
      assert {:ok, last_txi} = RocksDbCF.last_key(Model.Tx)
      assert {:ok, Model.tx(index: ^last_txi)} = RocksDbCF.fetch(Model.Tx, last_txi)
    end
  end

  describe "prev_key/2" do
    test "returns :not_found when there is no previous key" do
      assert :not_found = RocksDbCF.prev_key(Model.Tx, 0)
    end

    test "returns the previous key for integer" do
      assert :ok = RocksDbCF.put(Model.Tx, Model.tx(index: new_txi()))
      assert :ok = RocksDbCF.put(Model.Tx, Model.tx(index: new_txi()))
      RocksDb.commit()
      assert {:ok, 0} = RocksDbCF.prev_key(Model.Tx, 1)
    end

    test "returns the previous key for tuple" do
      assert :ok = RocksDbCF.put(Model.Block, Model.block(index: {0, -1}))
      assert :ok = RocksDbCF.put(Model.Block, Model.block(index: {1, -1}))
      RocksDb.commit()
      assert {:ok, {0, -1}} = RocksDbCF.prev_key(Model.Block, {0, nil})
    end
  end

  describe "next_key/2" do
    test "returns :not_found when there is no next key" do
      assert :not_found = RocksDbCF.next_key(Model.Tx, nil)
    end

    test "returns the next key for integer" do
      assert :ok = RocksDbCF.put(Model.Tx, Model.tx(index: new_txi()))
      assert :ok = RocksDbCF.put(Model.Tx, Model.tx(index: new_txi()))
      RocksDb.commit()
      assert {:ok, 2} = RocksDbCF.next_key(Model.Tx, 1)
    end

    test "returns the next key for tuple" do
      kbi1 = new_kbi()
      bi1 = {kbi1, -1}
      bi2 = {new_kbi(), -1}

      assert :ok = RocksDbCF.put(Model.Block, Model.block(index: bi1))
      assert :ok = RocksDbCF.put(Model.Block, Model.block(index: bi2))
      RocksDb.commit()
      assert {:ok, {^kbi1, -1}} = RocksDbCF.next_key(Model.Block, {kbi1, -2})
    end
  end

  describe "dirty_fetch/2" do
    test "returns :not_found when key does not exist" do
      assert :not_found = RocksDbCF.dirty_fetch(Model.Tx, :unknown)
    end

    test "returns the record from the transaction" do
      key = new_txi()

      m_tx =
        Model.tx(
          index: key,
          id: :crypto.strong_rand_bytes(32),
          block_index: {1234, 0},
          time: 5678
        )

      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      assert {:ok, ^m_tx} = RocksDbCF.dirty_fetch(Model.Tx, key)
    end

    test "returns the committed record of a key" do
      key = new_txi()

      m_tx =
        Model.tx(
          index: key,
          id: :crypto.strong_rand_bytes(32),
          block_index: {1234, 0},
          time: 5678
        )

      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      RocksDb.commit()
      assert {:ok, ^m_tx} = RocksDbCF.dirty_fetch(Model.Tx, key)
    end
  end

  describe "fetch/2" do
    test "returns :not_found when key does not exist" do
      assert :not_found = RocksDbCF.fetch(Model.Tx, :unknown)
    end

    test "returns :not_found for a record only in the transaction" do
      key = new_txi()
      assert :ok = RocksDbCF.put(Model.Tx, Model.tx(index: key))
      assert :not_found = RocksDbCF.fetch(Model.Tx, key)
    end

    test "returns the committed record of a key" do
      key = new_txi()

      m_tx =
        Model.tx(
          index: key,
          id: :crypto.strong_rand_bytes(32),
          block_index: {1234, 0},
          time: 5678
        )

      assert :ok = RocksDbCF.put(Model.Tx, m_tx)
      RocksDb.commit()
      assert {:ok, ^m_tx} = RocksDbCF.fetch(Model.Tx, key)
    end
  end

  #
  # Helpers
  #
  defp new_txi(), do: :ets.update_counter(:counters, :txi, {2, 1})
  defp new_kbi(), do: :ets.update_counter(:counters, :kbi, {2, 1})
end
