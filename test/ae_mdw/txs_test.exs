defmodule AeMdw.TxsTest do
  use ExUnit.Case

  import Mock

  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Txs

  require Model

  @height 5
  @mb0_time 1_000
  @mb1_time 4_000

  describe "tx_hash_to_tx/2" do
    setup do
      [tx10, tx11 | mb1_tx_hashes] = tx_hashes = for _i <- 10..14, do: new_hash()

      store =
        NullStore.new()
        |> MemStore.new()
        |> put_micro_block_txs({@height, 0}, @mb0_time, 10, [tx10, tx11])
        |> put_micro_block_txs({@height, 1}, @mb1_time, 12, mb1_tx_hashes)

      {:ok, mb_hash: new_hash(), tx_hashes: tx_hashes, store: store}
    end

    test "finds the tx by its position in the micro block without scanning the generation", %{
      mb_hash: mb_hash,
      tx_hashes: [_tx10, _tx11, tx12, tx13, tx14],
      store: store
    } do
      # no Model.Block rows, so the generation scan can't find anything
      state = State.new(store)

      with_node_micro_block(mb_hash, @mb1_time, [tx12, tx13, tx14], fn ->
        assert {:ok, Model.tx(index: 14, id: ^tx14)} = Txs.tx_hash_to_tx(state, tx14)
        assert {:ok, Model.tx(index: 12, id: ^tx12)} = Txs.tx_hash_to_tx(state, tx12)
      end)
    end

    test "falls back to the generation when a micro block of the previous generation has the same time",
         %{mb_hash: mb_hash, tx_hashes: [tx10, tx11 | _mb1_tx_hashes], store: store} do
      state =
        store
        |> put_micro_block_txs({@height - 1, 0}, @mb0_time, 8, [new_hash(), new_hash()])
        |> put_generation_blocks()
        |> State.new()

      with_node_micro_block(mb_hash, @mb0_time, [tx10, tx11], fn ->
        assert {:ok, Model.tx(index: 11, id: ^tx11)} = Txs.tx_hash_to_tx(state, tx11)
      end)
    end

    test "falls back to the generation without reading the node txs when mdw has no tx at the micro block time",
         %{mb_hash: mb_hash, tx_hashes: [_tx10, _tx11, tx12, tx13, tx14], store: store} do
      state = store |> put_generation_blocks() |> State.new()

      with_node_micro_block(mb_hash, @mb1_time + 1, [tx12, tx13, tx14], fn ->
        assert {:ok, Model.tx(index: 13, id: ^tx13)} = Txs.tx_hash_to_tx(state, tx13)
        assert_not_called(:aec_db.find_block_tx_hashes(:_))
      end)
    end

    test "returns not found when neither the micro block nor the generation has the tx", %{
      mb_hash: mb_hash,
      tx_hashes: [_tx10, _tx11, tx12, tx13, tx14],
      store: store
    } do
      state = store |> put_generation_blocks() |> State.new()
      missing_hash = new_hash()
      encoded_hash = :aeser_api_encoder.encode(:tx_hash, missing_hash)

      with_node_micro_block(mb_hash, @mb1_time, [tx12, tx13, tx14, missing_hash], fn ->
        assert {:error,
                %ErrInput{reason: ErrInput.NotFound, message: "not found: " <> ^encoded_hash}} =
                 Txs.tx_hash_to_tx(state, missing_hash)
      end)
    end

    test "returns not found when the node has no micro block for the tx", %{store: store} do
      state = State.new(store)

      [mempool_tx, unlocated_tx, unknown_tx, headerless_tx, unknown_mb_hash] =
        for _i <- 1..5, do: new_hash()

      with_mocks [
        {:aec_db, [:passthrough],
         [
           find_tx_location: fn
             ^mempool_tx -> :mempool
             ^unlocated_tx -> :none
             ^unknown_tx -> :not_found
             ^headerless_tx -> unknown_mb_hash
           end,
           find_header: fn ^unknown_mb_hash -> :none end
         ]}
      ] do
        for tx_hash <- [mempool_tx, unlocated_tx, unknown_tx, headerless_tx] do
          assert {:error, %ErrInput{reason: ErrInput.NotFound}} =
                   Txs.tx_hash_to_tx(state, tx_hash)
        end
      end
    end
  end

  defp with_node_micro_block(mb_hash, mb_time, node_tx_hashes, fun) do
    with_mocks [
      {:aec_db, [:passthrough],
       [
         find_tx_location: fn _tx_hash -> mb_hash end,
         find_header: fn ^mb_hash -> {:value, :mb_header} end,
         find_block_tx_hashes: fn ^mb_hash -> {:value, node_tx_hashes} end
       ]},
      {:aec_headers, [:passthrough],
       [height: fn :mb_header -> @height end, time_in_msecs: fn :mb_header -> mb_time end]}
    ] do
      fun.()
    end
  end

  defp put_micro_block_txs(store, block_index, mb_time, first_txi, tx_hashes) do
    tx_hashes
    |> Enum.with_index(first_txi)
    |> Enum.reduce(store, fn {tx_hash, txi}, store ->
      store
      |> Store.put(Model.Tx, Model.tx(index: txi, id: tx_hash, block_index: block_index))
      |> Store.put(Model.Time, Model.time(index: {mb_time, txi}))
    end)
  end

  defp put_generation_blocks(store) do
    store
    |> Store.put(Model.Block, Model.block(index: {@height, -1}, tx_index: 10))
    |> Store.put(Model.Block, Model.block(index: {@height, 0}, tx_index: 10))
    |> Store.put(Model.Block, Model.block(index: {@height, 1}, tx_index: 12))
    |> Store.put(Model.Block, Model.block(index: {@height + 1, -1}, tx_index: 15))
  end

  defp new_hash(), do: :crypto.strong_rand_bytes(32)
end
