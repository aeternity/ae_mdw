defmodule AeMdw.DatabaseTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  import AeMdw.Db.ModelFixtures, only: [new_block: 0]

  require Model

  describe "transaction_commit/1" do
    test "persists a single mutation within a transaction" do
      Model.block(index: key) = m_block = new_block()

      commit([
        WriteMutation.new(Model.Block, m_block)
      ])

      assert {:ok, ^m_block} = Database.fetch(Model.Block, key)
      assert :ok = Database.dirty_delete(Model.Block, key)
      assert :not_found == Database.fetch(Model.Block, key)
    end

    test "persists multiple mutations within a transaction" do
      {txn_mutations, records} =
        Enum.reduce(1..100, {[], []}, fn _i, {txn_mutations_acc, records_acc} ->
          m_block = new_block()
          txn_mutation = WriteMutation.new(Model.Block, m_block)

          {
            [txn_mutation | txn_mutations_acc],
            [m_block | records_acc]
          }
        end)

      commit(txn_mutations)

      Enum.each(records, fn Model.block(index: key) = m_block ->
        assert {:ok, ^m_block} = Database.fetch(Model.Block, key)
        assert :ok = Database.dirty_delete(Model.Block, key)
        assert :not_found == Database.fetch(Model.Block, key)
      end)
    end

    test "persists nested mutations within a transaction" do
      {txn_mutations, records} =
        Enum.reduce(1..10, {[], []}, fn _i, {txn_mutations_acc, records_acc} ->
          m_block = new_block()
          txn_mutation = WriteMutation.new(Model.Block, m_block)

          {
            [txn_mutation | txn_mutations_acc],
            [m_block | records_acc]
          }
        end)

      {txn_mutations1, txn_mutations2} = Enum.split(txn_mutations, 5)

      commit([
        txn_mutations1,
        txn_mutations2
      ])

      Enum.each(records, fn Model.block(index: key) = m_block ->
        assert {:ok, ^m_block} = Database.fetch(Model.Block, key)
        assert :ok = Database.dirty_delete(Model.Block, key)
        assert :not_found == Database.fetch(Model.Block, key)
      end)
    end

    test "persists nested nil mutations within a transaction" do
      {txn_mutations, records} =
        Enum.reduce(1..10, {[], []}, fn _i, {txn_mutations_acc, records_acc} ->
          m_block = new_block()
          txn_mutation = WriteMutation.new(Model.Block, m_block)

          {
            [txn_mutation | txn_mutations_acc],
            [m_block | records_acc]
          }
        end)

      {txn_mutations1, txn_mutations2} = Enum.split(txn_mutations, 5)

      commit([
        txn_mutations1,
        [nil],
        txn_mutations2
      ])

      Enum.each(records, fn Model.block(index: key) = m_block ->
        assert {:ok, ^m_block} = Database.fetch(Model.Block, key)
        assert :ok = Database.dirty_delete(Model.Block, key)
        assert :not_found == Database.fetch(Model.Block, key)
      end)
    end
  end

  describe "delete/3" do
    test "raises error when key doesn't exist" do
      txn = Database.transaction_new()
      Database.write(txn, Model.Block, Model.block(index: {123, 0}))

      refute :not_found == Database.dirty_fetch(txn, Model.Block, {123, 0})
      assert :ok = Database.delete(txn, Model.Block, {123, 0})

      assert_raise RuntimeError, "Txn delete on missing key: #{Model.Block}, {123, 0}", fn ->
        Database.delete(txn, Model.Block, {123, 0})
      end
    end
  end

  defp commit(mutations), do: State.commit(State.new(), mutations)
end
