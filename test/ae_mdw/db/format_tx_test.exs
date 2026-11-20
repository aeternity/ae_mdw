defmodule AeMdw.Db.FormatTxTest do
  use ExUnit.Case, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Format
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State

  import Mock

  require Model

  setup do
    {:ok, aetx} =
      :aec_spend_tx.new(%{
        sender_id: :aeser_id.create(:account, <<1::256>>),
        recipient_id: :aeser_id.create(:account, <<2::256>>),
        amount: 3,
        fee: 4,
        nonce: 5,
        payload: "x"
      })

    signed_tx = :aetx_sign.new(aetx, [<<6::512>>])
    height = 123
    time = 1_700_000_000_000

    mblock =
      :aec_blocks.new_micro(
        height,
        <<7::256>>,
        <<8::256>>,
        <<>>,
        <<>>,
        [signed_tx],
        time,
        :no_fraud,
        0
      )

    header = :aec_blocks.to_header(mblock)
    {:ok, mb_hash} = :aec_headers.hash_header(header)
    tx_hash = :aetx_sign.hash(signed_tx)
    m_tx = Model.tx(index: 9, id: tx_hash, block_index: {height, 2}, time: time)

    expected =
      header
      |> :aetx_sign.serialize_for_client(signed_tx)
      |> Map.merge(%{"tx_index" => 9, "micro_index" => 2, "micro_time" => time})

    {:ok,
     signed_tx: signed_tx,
     header: header,
     mb_hash: mb_hash,
     tx_hash: tx_hash,
     m_tx: m_tx,
     time: time,
     expected: expected}
  end

  describe "to_map/2 and to_raw_map/2" do
    test "take the block from the mdw block row and read only the signed tx", %{
      signed_tx: signed_tx,
      mb_hash: mb_hash,
      tx_hash: tx_hash,
      m_tx: m_tx,
      expected: expected
    } do
      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.Block, Model.block(index: {123, 2}, hash: mb_hash))

      with_mocks [
        {:aec_db, [:passthrough], [find_signed_tx: fn ^tx_hash -> {:value, signed_tx} end]}
      ] do
        assert expected == Format.to_map(state, m_tx)
        assert %{block_hash: ^mb_hash, signatures: [<<6::512>>]} = Format.to_raw_map(state, m_tx)

        assert_not_called(:aec_db.find_tx_with_location(:_))
        assert_not_called(:aec_db.get_header(:_))
      end
    end

    test "with a block row, render from mdw rows when the node has no signed tx", %{
      mb_hash: mb_hash,
      tx_hash: tx_hash,
      m_tx: m_tx,
      time: time
    } do
      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.Block, Model.block(index: {123, 2}, hash: mb_hash))
        |> State.put(Model.Type, Model.type(index: {:spend_tx, 9}))

      with_mocks [{:aec_db, [:passthrough], [find_signed_tx: fn ^tx_hash -> :none end]}] do
        assert %{
                 "block_hash" => Enc.encode(:micro_block_hash, mb_hash),
                 "block_height" => 123,
                 "encoded_tx" => nil,
                 "hash" => Enc.encode(:tx_hash, tx_hash),
                 "micro_index" => 2,
                 "micro_time" => time,
                 "signatures" => [],
                 "tx" => %{"type" => "SpendTx"},
                 "tx_index" => 9
               } == Format.to_map(state, m_tx)

        assert %{
                 block_hash: mb_hash,
                 signatures: [],
                 hash: tx_hash,
                 block_height: 123,
                 micro_index: 2,
                 micro_time: time,
                 tx_index: 9,
                 tx: %{type: :spend_tx}
               } == Format.to_raw_map(state, m_tx)

        assert_not_called(:aec_db.find_tx_with_location(:_))
      end
    end

    test "without a block row, take the block from the node tx location", %{
      signed_tx: signed_tx,
      header: header,
      mb_hash: mb_hash,
      tx_hash: tx_hash,
      m_tx: m_tx,
      expected: expected
    } do
      state = State.new(MemStore.new(NullStore.new()))

      with_mocks [
        {:aec_db, [:passthrough],
         [
           find_tx_with_location: fn ^tx_hash -> {mb_hash, signed_tx} end,
           get_header: fn ^mb_hash -> header end
         ]}
      ] do
        assert expected == Format.to_map(state, m_tx)
        assert %{block_hash: ^mb_hash} = Format.to_raw_map(state, m_tx)
      end
    end
  end
end
