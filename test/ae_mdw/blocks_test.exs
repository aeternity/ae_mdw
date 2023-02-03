defmodule AeMdw.BlocksTest do
  use ExUnit.Case

  alias AeMdw.Db.State
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Store
  alias AeMdw.Blocks

  require Model

  describe "fetch_txis_from_gen/2" do
    test "returns the range of txis from any two blocks" do
      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 0))
        |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 0))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 0))
        |> Store.put(Model.Block, Model.block(index: {1, 0}, tx_index: 10))
        |> Store.put(Model.Block, Model.block(index: {1, 1}, tx_index: 20))
        |> Store.put(Model.Block, Model.block(index: {2, -1}, tx_index: 30))
        |> Store.put(Model.Block, Model.block(index: {2, 0}, tx_index: 30))
        |> Store.put(Model.Tx, Model.tx(index: 34))
        |> State.new()

      assert [] = Enum.to_list(Blocks.fetch_txis_from_gen(state, 0))
      assert Enum.to_list(0..29) == Enum.to_list(Blocks.fetch_txis_from_gen(state, 1))
      assert Enum.to_list(30..34) == Enum.to_list(Blocks.fetch_txis_from_gen(state, 2))
    end
  end
end
