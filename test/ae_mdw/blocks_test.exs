defmodule AeMdw.BlocksTest do
  use ExUnit.Case

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.TestSamples, as: TS
  alias AeMdw.Db.State
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Store
  alias AeMdw.Blocks

  import Mock

  require Model

  describe "fetch_txis_from_gen/2" do
    test "returns empty list when there are no transactions" do
      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 0))
        |> State.new()

      assert [] = Enum.to_list(Blocks.fetch_txis_from_gen(state, 0))
    end

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

  describe "fetch_key_block/2" do
    test "uses state fallback when node db can't resolve hash height" do
      kbi = 1
      block_hash = TS.key_block_hash(kbi)
      encoded_hash = Enc.encode(:key_block_hash, block_hash)

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(
          Model.Block,
          Model.block(index: {0, -1}, tx_index: 0, hash: TS.key_block_hash(0))
        )
        |> Store.put(Model.Block, Model.block(index: {kbi, -1}, tx_index: 0, hash: block_hash))
        |> State.new()

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           find_block_height: fn ^block_hash -> :none end,
           prev_block_type: fn :header -> :micro end
         ]},
        {:aec_db, [], [get_header: fn ^block_hash -> :header end]},
        {:aec_headers, [], [serialize_for_client: fn :header, :micro -> %{height: kbi} end]}
      ] do
        assert {:ok, %{height: ^kbi, hash: ^encoded_hash}} =
                 Blocks.fetch_key_block(state, encoded_hash)
      end
    end
  end
end
