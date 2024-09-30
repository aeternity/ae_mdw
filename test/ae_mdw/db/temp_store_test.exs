defmodule AeMdw.Db.TempStoreTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.TempStore
  alias AeMdw.Db.Store
  alias AeMdw.Db.WriteMutation

  require Model

  test "it puts and reads values" do
    temp_store = TempStore.new()

    temp_store =
      temp_store
      |> Store.put(Model.Block, Model.block(index: {4, 0}, hash: :val4))
      |> Store.put(Model.Block, Model.block(index: {1, 0}, hash: :val1))
      |> Store.put(Model.Block, Model.block(index: {3, 0}, hash: :old_val))
      |> Store.put(Model.Block, Model.block(index: {3, 0}, hash: :val3))
      |> Store.put(Model.Block, Model.block(index: {2, 0}, hash: :val1))
      |> Store.delete(Model.Block, {2, 0})

    assert 3 = Store.count_keys(temp_store, Model.Block)

    assert {:ok, Model.block(index: {3, 0}, hash: :val3)} =
             Store.get(temp_store, Model.Block, {3, 0})

    assert :not_found = Store.get(temp_store, Model.Block, {2, 0})

    assert :none = Store.next(temp_store, Model.Block, {4, 0})
  end

  test "it generates mutations based on contents" do
    temp_store = TempStore.new()

    temp_store =
      temp_store
      |> Store.put(Model.Block, Model.block(index: {1, 0}, hash: :val1))
      |> Store.put(Model.Block, Model.block(index: {2, 0}, hash: :val2))
      |> Store.put(Model.Block, Model.block(index: {3, 0}, hash: :val3))

    assert [
             %WriteMutation{table: Model.Block, record: Model.block(index: {1, 0}, hash: :val1)},
             %WriteMutation{table: Model.Block, record: Model.block(index: {2, 0}, hash: :val2)},
             %WriteMutation{table: Model.Block, record: Model.block(index: {3, 0}, hash: :val3)}
           ] = temp_store |> TempStore.to_mutations() |> Enum.to_list()
  end
end
