defmodule AeMdwWeb.BlockControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.TestSamples, as: TS
  alias AeMdw.Validate

  import Mock
  import AeMdwWeb.BlockchainSim
  import AeMdw.Util.Encoding, only: [encode_block: 2]

  require Model

  @hashes List.flatten(for i <- 0..2, do: [TS.key_block_hash(i), TS.micro_block_hash(i)])

  describe "key-blocks" do
    test "it gets all key blocks with the appropriate micro_blocks_count", %{
      conn: conn,
      store: store
    } do
      kbi = 1
      hash = TS.key_block_hash(1)

      store =
        store
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi - 1, -1}, tx_index: 0, hash: TS.key_block_hash(0))
        )
        |> Store.put(Model.Block, Model.block(index: {kbi, -1}, tx_index: 0, hash: hash))
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 0}, tx_index: 0, hash: TS.micro_block_hash(0))
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 1}, tx_index: 0, hash: TS.micro_block_hash(1))
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 2}, tx_index: 0, hash: TS.micro_block_hash(2))
        )
        |> Store.put(Model.DeltaStat, Model.delta_stat(index: kbi, block_reward: 5000))

      with_mocks [
        {:aec_db, [], [get_header: fn ^hash -> :header end]},
        {AeMdw.Node.Db, [],
         [
           prev_block_type: fn :header -> :micro end,
           find_block_height: fn hash when hash in @hashes -> {:ok, kbi} end
         ]},
        {:aec_headers, [], [serialize_for_client: fn :header, :micro -> %{height: kbi} end]}
      ] do
        assert %{"data" => [block]} =
                 conn
                 |> with_store(store)
                 |> get("/v3/key-blocks", limit: 1)
                 |> json_response(200)

        assert %{
                 "height" => ^kbi,
                 "micro_blocks_count" => 3
               } = block
      end
    end

    test "it gets all key blocks with the appropriate transactions_count", %{
      conn: conn,
      store: store
    } do
      kbi = 1
      hash = TS.key_block_hash(1)

      store =
        store
        |> Store.put(Model.Block, Model.block(index: {kbi - 1, -1}, hash: TS.key_block_hash(0)))
        |> Store.put(Model.Block, Model.block(index: {kbi, -1}, hash: hash, tx_index: 4))
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 0}, hash: TS.micro_block_hash(0), tx_index: 0)
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi + 1, -1}, hash: TS.key_block_hash(2), tx_index: 10)
        )
        |> Store.put(Model.DeltaStat, Model.delta_stat(index: kbi, block_reward: 5000))
        |> Store.put(Model.DeltaStat, Model.delta_stat(index: kbi - 1, block_reward: 5000 - 1))

      with_mocks [
        {:aec_db, [], [get_header: fn ^hash -> :header end]},
        {AeMdw.Node.Db, [],
         [
           prev_block_type: fn :header -> :micro end,
           find_block_height: fn hash when hash in @hashes -> {:ok, kbi} end
         ]},
        {:aec_headers, [], [serialize_for_client: fn :header, :micro -> %{height: kbi} end]}
      ] do
        assert %{"data" => [block]} =
                 conn
                 |> with_store(store)
                 |> get("/v3/key-blocks", limit: 1, scope: "gen:#{kbi}")
                 |> json_response(200)

        assert %{
                 "height" => ^kbi,
                 "transactions_count" => 6
               } = block
      end
    end
  end

  describe "key_block_micro_blocks" do
    test "it gets all micro blocks with the appropriate transactions_count", %{
      conn: conn,
      store: store
    } do
      kbi = 1
      hash = TS.key_block_hash(1)
      encoded_hash = Enc.encode(:key_block_hash, hash)

      store =
        store
        |> Store.put(Model.Block, Model.block(index: {kbi, -1}, tx_index: 0, hash: hash))
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 0}, tx_index: 0, hash: TS.micro_block_hash(0))
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 1}, tx_index: 10, hash: TS.micro_block_hash(1))
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 2}, tx_index: 15, hash: TS.micro_block_hash(2))
        )
        |> Store.put(Model.Block, Model.block(index: {kbi + 1, -1}, tx_index: 17, hash: hash))

      with_mocks [
        {:aec_db, [], [get_header: fn _mb_hash -> :header end]},
        {:aec_chain, [], [get_block: fn ^hash -> {:ok, :block} end]},
        {:aec_blocks, [], [to_header: fn :block -> :header end]},
        {AeMdw.Node.Db, [],
         [
           prev_block_type: fn :header -> :micro end,
           find_block_height: fn hash when hash in @hashes -> {:ok, kbi} end
         ]},
        {:aec_headers, [],
         [
           type: fn :header -> :key end,
           height: fn :header -> kbi end,
           serialize_for_client: fn :header, :micro -> %{height: kbi} end
         ]}
      ] do
        assert %{"data" => [block3, block2, block1]} =
                 conn
                 |> with_store(store)
                 |> get("/v3/key-blocks/#{encoded_hash}/micro-blocks")
                 |> json_response(200)

        assert %{
                 "height" => ^kbi,
                 "transactions_count" => 10
               } = block1

        assert %{
                 "height" => ^kbi,
                 "transactions_count" => 5
               } = block2

        assert %{
                 "height" => ^kbi,
                 "transactions_count" => 2
               } = block3
      end
    end

    test "when key block doesn't exist, it returns 404", %{conn: conn, store: store} do
      decoded_hash = TS.key_block_hash(1)
      encoded_hash = Enc.encode(:key_block_hash, decoded_hash)
      error_msg = "not found: #{encoded_hash}"

      store =
        Store.put(store, Model.Block, Model.block(index: {0, -1}, hash: TS.key_block_hash(0)))

      with_mocks [
        {:aec_chain, [], [get_block: fn ^decoded_hash -> :error end]}
      ] do
        assert %{"error" => ^error_msg} =
                 conn
                 |> with_store(store)
                 |> get("/v3/key-blocks/#{encoded_hash}/micro-blocks")
                 |> json_response(404)
      end
    end

    test "when key block hash is invalid, it returns 400", %{conn: conn} do
      encoded_hash = "asdadads"
      error_msg = "invalid hash: #{encoded_hash}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/key-blocks/#{encoded_hash}/micro-blocks")
               |> json_response(400)
    end
  end

  describe "key-block" do
    test "it gets blocks by kbi", %{conn: conn, store: store} do
      kbi = 1
      decoded_hash = TS.key_block_hash(1)

      store =
        store
        |> Store.put(Model.Block, Model.block(index: {kbi - 1, -1}, hash: TS.key_block_hash(0)))
        |> Store.put(Model.Block, Model.block(index: {kbi, -1}, hash: decoded_hash, tx_index: 4))
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 0}, hash: TS.micro_block_hash(0), tx_index: 4)
        )
        |> Store.put(Model.DeltaStat, Model.delta_stat(index: kbi - 1, block_reward: 5000 - 1))
        |> Store.put(Model.DeltaStat, Model.delta_stat(index: kbi, block_reward: 5000))

      with_mocks [
        {:aec_db, [], [get_header: fn ^decoded_hash -> :header end]},
        {:aec_headers, [], [serialize_for_client: fn :header, :micro -> %{height: kbi} end]},
        {AeMdw.Node.Db, [],
         [
           prev_block_type: fn :header -> :micro end,
           find_block_height: fn hash when hash in @hashes -> {:ok, kbi} end
         ]}
      ] do
        assert %{
                 "height" => ^kbi,
                 "micro_blocks_count" => 1,
                 "transactions_count" => 0
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/key-blocks/#{kbi}")
                 |> json_response(200)
      end
    end

    test "it returns a block with txs counts", %{conn: conn, store: store} do
      kbi = 1
      decoded_hash = TS.key_block_hash(1)
      encoded_hash = :aeser_api_encoder.encode(:key_block_hash, decoded_hash)

      store =
        store
        |> Store.put(Model.Block, Model.block(index: {kbi - 1, -1}, hash: TS.key_block_hash(0)))
        |> Store.put(Model.Block, Model.block(index: {kbi, -1}, hash: decoded_hash, tx_index: 4))
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 0}, hash: TS.micro_block_hash(0), tx_index: 0)
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi + 1, -1}, hash: TS.key_block_hash(2), tx_index: 10)
        )
        |> Store.put(Model.DeltaStat, Model.delta_stat(index: kbi - 1, block_reward: 5000 - 1))
        |> Store.put(Model.DeltaStat, Model.delta_stat(index: kbi, block_reward: 5000))

      with_mocks [
        {:aec_chain, [], [get_block: fn ^decoded_hash -> {:ok, :block} end]},
        {:aec_db, [], [get_header: fn ^decoded_hash -> :header end]},
        {:aec_blocks, [], [to_header: fn :block -> :header end]},
        {:aec_headers, [],
         [
           height: fn :header -> kbi end,
           serialize_for_client: fn :header, :micro -> %{height: kbi} end,
           type: fn :header -> :key end
         ]},
        {AeMdw.Node.Db, [],
         [
           prev_block_type: fn :header -> :micro end,
           find_block_height: fn hash when hash in @hashes -> {:ok, kbi} end
         ]}
      ] do
        assert %{
                 "height" => ^kbi,
                 "transactions_count" => 6
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/key-blocks/#{encoded_hash}")
                 |> json_response(200)
      end
    end

    test "it returns 404 when not found", %{conn: conn, store: store} do
      decoded_hash = TS.key_block_hash(0)
      encoded_hash = :aeser_api_encoder.encode(:key_block_hash, decoded_hash)
      error_msg = "not found: #{encoded_hash}"

      store =
        Store.put(store, Model.Block, Model.block(index: {0, -1}, hash: TS.key_block_hash(0)))

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v3/key-blocks/#{encoded_hash}")
               |> json_response(404)
    end
  end

  describe "micro-block" do
    test "it returns a micro block with txs counts", %{conn: conn, store: store} do
      kbi = 1
      decoded_hash = TS.micro_block_hash(0)
      encoded_hash = :aeser_api_encoder.encode(:micro_block_hash, decoded_hash)

      store =
        store
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, -1}, hash: TS.key_block_hash(0), tx_index: 4)
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 0}, hash: decoded_hash, tx_index: 4)
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 1}, hash: TS.micro_block_hash(1), tx_index: 10)
        )

      with_mocks [
        {:aec_chain, [], [get_block: fn ^decoded_hash -> {:ok, :block} end]},
        {:aec_db, [], [get_header: fn ^decoded_hash -> :header end]},
        {:aec_blocks, [], [to_header: fn :block -> :header end]},
        {:aec_headers, [],
         [
           height: fn :header -> kbi end,
           serialize_for_client: fn :header, :key -> %{height: kbi} end,
           type: fn :header -> :micro end
         ]},
        {AeMdw.Node.Db, [],
         [
           prev_block_type: fn :header -> :key end,
           get_reverse_micro_blocks: fn ^decoded_hash -> [] end,
           find_block_height: fn hash when hash in @hashes -> {:ok, kbi} end
         ]}
      ] do
        assert %{
                 "height" => ^kbi,
                 "micro_block_index" => 0,
                 "transactions_count" => 6
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/micro-blocks/#{encoded_hash}")
                 |> json_response(200)
      end
    end

    test "when last micro block, it returns a micro block with txs counts", %{
      conn: conn,
      store: store
    } do
      kbi = 1
      decoded_hash = TS.micro_block_hash(0)
      encoded_hash = :aeser_api_encoder.encode(:micro_block_hash, decoded_hash)

      store =
        store
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, -1}, hash: TS.key_block_hash(0), tx_index: 4)
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {kbi, 0}, hash: decoded_hash, tx_index: 4)
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: 9, block_index: {kbi, 0})
        )

      with_mocks [
        {:aec_chain, [], [get_block: fn ^decoded_hash -> {:ok, :block} end]},
        {:aec_db, [], [get_header: fn ^decoded_hash -> :header end]},
        {:aec_blocks, [], [to_header: fn :block -> :header end]},
        {:aec_headers, [],
         [
           height: fn :header -> kbi end,
           serialize_for_client: fn :header, :key -> %{height: kbi} end,
           type: fn :header -> :micro end
         ]},
        {AeMdw.Node.Db, [],
         [
           prev_block_type: fn :header -> :key end,
           get_reverse_micro_blocks: fn ^decoded_hash -> [] end,
           find_block_height: fn hash when hash in @hashes -> {:ok, kbi} end
         ]}
      ] do
        assert %{
                 "height" => ^kbi,
                 "micro_block_index" => 0,
                 "transactions_count" => 6
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/micro-blocks/#{encoded_hash}")
                 |> json_response(200)
      end
    end

    test "it returns 404 when not found", %{conn: conn, store: store} do
      decoded_hash = TS.micro_block_hash(0)
      encoded_hash = :aeser_api_encoder.encode(:micro_block_hash, decoded_hash)
      error_msg = "not found: #{encoded_hash}"

      store =
        Store.put(store, Model.Block, Model.block(index: {0, -1}, hash: TS.key_block_hash(0)))

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v3/micro-blocks/#{encoded_hash}")
               |> json_response(404)
    end
  end

  describe "blocks" do
    test "get key block by hash", %{conn: conn, store: store} do
      with_blockchain %{}, kb1: [] do
        %{hash: kb_hash, height: kbi} = blocks[:kb1]

        store =
          Store.put(
            store,
            Model.Block,
            Model.block(index: {kbi, -1}, hash: Validate.id!(kb_hash))
          )

        assert response_data =
                 %{"hash" => ^kb_hash} =
                 conn |> with_store(store) |> get("/v2/blocks/#{kb_hash}") |> json_response(200)

        refute Map.has_key?(response_data, "micro_blocks")
      end
    end

    test "get microblock by hash", %{conn: conn, store: store} do
      with_blockchain %{alice: 10_000, bob: 20_000},
        mb1: [
          t1: spend_tx(:alice, :bob, 5_000)
        ] do
        %{hash: mb_hash, height: kbi} = blocks[:mb1]

        store =
          Store.put(
            store,
            Model.Block,
            Model.block(index: {kbi, 0}, hash: Validate.id!(mb_hash))
          )

        assert response_data =
                 %{"hash" => ^mb_hash} =
                 conn |> with_store(store) |> get("/v2/blocks/#{mb_hash}") |> json_response(200)

        refute Map.has_key?(response_data, "micro_blocks")
      end
    end

    test "get generation blocks with microblocks", %{conn: conn, store: store} do
      with_blockchain %{alice: 10_000, bob: 20_000},
        kb1: [
          mb1: [
            t1: spend_tx(:alice, :bob, 5_000)
          ],
          mb2: [
            t2: spend_tx(:bob, :alice, 3_000)
          ]
        ] do
        %{hash: kb1_hash, height: kbi} = blocks[:kb1]
        %{hash: mb1_hash, time: mb_time1} = blocks[:mb1]
        %{hash: mb2_hash, time: mb_time2} = blocks[:mb2]

        store =
          store
          |> Store.put(
            Model.Block,
            Model.block(index: {kbi, -1}, hash: Validate.id!(kb1_hash))
          )
          |> Store.put(
            Model.Block,
            Model.block(index: {kbi, 0}, hash: Validate.id!(mb1_hash))
          )
          |> Store.put(
            Model.Block,
            Model.block(index: {kbi, 1}, hash: Validate.id!(mb2_hash))
          )

        assert %{"hash" => ^kb1_hash, "micro_blocks" => mbs} =
                 conn |> with_store(store) |> get("/v2/blocks/#{kbi}") |> json_response(200)

        assert [
                 %{"hash" => ^mb1_hash, "time" => ^mb_time1},
                 %{"hash" => ^mb2_hash, "time" => ^mb_time2}
               ] = mbs

        assert mbs == Enum.sort_by(mbs, & &1["time"]) and mb_time1 != 0 and mb_time2 != 0
      end
    end

    test "renders bad request when the hash is invalid", %{conn: conn} do
      hash = "kh_InvalidHash"
      error_msg = "invalid id: #{hash}"

      assert %{"error" => ^error_msg} = conn |> get("/v2/blocks/#{hash}") |> json_response(400)
    end

    test "renders not found when hash is unknown", %{conn: conn} do
      unknown_kb_hash = encode_block(:key, :crypto.strong_rand_bytes(32))
      error_msg = "not found: #{unknown_kb_hash}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/blocks/#{unknown_kb_hash}") |> json_response(404)
    end

    test "renders not found when height is unknown", %{conn: conn, store: store} do
      unknown_height = Enum.random(100_000..999_999)
      error_msg = "not found: #{unknown_height}"

      store =
        Store.put(
          store,
          Model.Block,
          Model.block(index: {0, 0}, hash: :crypto.strong_rand_bytes(32))
        )

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v2/blocks/#{unknown_height}")
               |> json_response(404)
    end
  end

  describe "block_v1" do
    test "get key block by hash", %{conn: conn} do
      with_blockchain %{alice: 10_000}, b1: [] do
        %{hash: kb_hash} = blocks[:b1]

        assert %{"hash" => ^kb_hash} = conn |> get("/block/#{kb_hash}") |> json_response(200)
      end
    end

    test "get micro block by hash", %{conn: conn} do
      with_blockchain %{alice: 10_000, bob: 20_000},
        mb1: [
          t1: spend_tx(:alice, :bob, 5_000)
        ] do
        %{hash: mb_hash} = blocks[:mb1]

        assert %{"hash" => ^mb_hash} = conn |> get("/block/#{mb_hash}") |> json_response(200)
      end
    end

    test "renders bad request when the hash is invalid", %{conn: conn} do
      hash = "kh_InvalidHash"
      error_msg = "invalid id: #{hash}"
      assert %{"error" => ^error_msg} = conn |> get("/block/#{hash}") |> json_response(400)
    end
  end
end
