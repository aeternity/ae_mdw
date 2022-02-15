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

  #
  # Helpers
  #
  defp new_txi(), do: :ets.update_counter(:counters, :txi, {2, 1})
end
