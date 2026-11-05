defmodule AeMdw.Db.MemStoreTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.DbStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.StepwiseStream
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

      assert [{1, 0}, {3, 0}, {4, 0}] =
               mem_store2 |> Store.stream(Model.Block, :forward, nil) |> Enum.to_list()

      assert [{1, 0}] =
               mem_store2 |> Store.stream(Model.Block, :backward, {2, 0}) |> Enum.to_list()
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

      assert [{2, 0}, {3, 0}, {6, 0}, {7, 0}] =
               mem_store2 |> Store.stream(Model.Block, :forward, nil) |> Enum.to_list()

      assert [{3, 0}, {2, 0}] =
               mem_store2 |> Store.stream(Model.Block, :backward, {5, 0}) |> Enum.to_list()
    end
  end

  describe "stream/4 when the fallback is the database" do
    test "returns the keys that next/3 and prev/3 return, from any start" do
      height = Enum.random(1_000_000_000..9_999_999_999)
      write_blocks(height, 0..30//3)

      mem_store =
        [1, 4, 10, 30, 31]
        |> Enum.reduce(MemStore.new(DbStore.new()), fn mbi, store ->
          Store.put(store, Model.Block, Model.block(index: {height, mbi}))
        end)
        |> then(fn store ->
          Enum.reduce([0, 6, 10, 12, 15, 18], store, &Store.delete(&2, Model.Block, {height, &1}))
        end)

      for start_key <- [nil | Enum.map(-1..32, &{height, &1})],
          direction <- [:forward, :backward] do
        assert mem_store
               |> StepwiseStream.stream(Model.Block, direction, start_key)
               |> Enum.take(8) ==
                 mem_store |> Store.stream(Model.Block, direction, start_key) |> Enum.take(8)
      end
    end

    test "sees the changes made while streaming" do
      height = Enum.random(1_000_000_000..9_999_999_999)
      write_blocks(height, 0..18//2)
      mem_store = MemStore.new(DbStore.new())

      keys =
        mem_store
        |> Store.stream(Model.Block, :forward, {height, 0})
        |> Stream.take_while(&match?({^height, _mbi}, &1))
        |> Stream.each(fn
          {^height, 4} ->
            mem_store
            |> Store.delete(Model.Block, {height, 4})
            |> Store.delete(Model.Block, {height, 8})
            |> Store.put(Model.Block, Model.block(index: {height, 9}))

          _key ->
            :ok
        end)
        |> Enum.to_list()

      assert Enum.map([0, 2, 4, 6, 9, 10, 12, 14, 16, 18], &{height, &1}) == keys
    end
  end

  defp write_blocks(height, mbis) do
    Enum.each(mbis, &Database.dirty_write(Model.Block, Model.block(index: {height, &1})))
    on_exit(fn -> Enum.each(mbis, &Database.dirty_delete(Model.Block, {height, &1})) end)
  end
end
