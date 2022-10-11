defmodule AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.Util
  alias AeMdw.Node.Db
  alias AeMdw.TestSamples, as: TS

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, oracle_register_tx: 2]
  import Mock

  require Model

  describe "txs" do
    test "it returns 400 when no direction specified", %{conn: conn} do
      with_mocks [
        {Util, [],
         [
           last_gen: fn _state -> 1_000 end
         ]}
      ] do
        assert %{"error" => "no such route"} = conn |> get("/txs") |> json_response(400)
      end
    end
  end

  describe "tx" do
    test "returns 404 when tx location is not a block hash", %{conn: conn} do
      tx_hash1 = :crypto.strong_rand_bytes(32)
      tx_hash2 = :crypto.strong_rand_bytes(32)
      tx_hash3 = :crypto.strong_rand_bytes(32)

      with_mocks [
        {:aec_db, [:passthrough],
         [
           find_tx_location: fn
             ^tx_hash1 -> :none
             ^tx_hash2 -> :not_found
             ^tx_hash3 -> :mempool
           end
         ]}
      ] do
        tx_hash1 = encode(:tx_hash, tx_hash1)
        tx_hash2 = encode(:tx_hash, tx_hash2)
        tx_hash3 = encode(:tx_hash, tx_hash3)

        assert %{"error" => _error_msg} = conn |> get("/tx/#{tx_hash1}") |> json_response(404)
        assert %{"error" => _error_msg} = conn |> get("/tx/#{tx_hash2}") |> json_response(404)
        assert %{"error" => _error_msg} = conn |> get("/tx/#{tx_hash3}") |> json_response(404)
      end
    end

    test "returns an oracle_register_tx with non-string format fields", %{
      conn: conn,
      store: store
    } do
      with_blockchain %{alice: 10_000},
        mb: [
          tx: oracle_register_tx(:alice, %{query_format: <<0, 160>>, response_format: <<225>>})
        ] do
        %{txs: [tx]} = blocks[:mb]

        {:id, :account, alice_pk} = accounts[:alice]
        alice_id = encode(:account_pubkey, alice_pk)
        oracle_id = encode(:oracle_pubkey, alice_pk)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {0, 0}, id: :aetx_sign.hash(tx)))
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 2))

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx))

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "account_id" => ^alice_id,
                   "oracle_id" => ^oracle_id,
                   "query_format" => [0, 160],
                   "response_format" => [225]
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{tx_hash}")
                 |> json_response(200)
      end
    end

    test "returns an oracle_register_tx with utf8 format fields", %{conn: conn, store: store} do
      with_blockchain %{alice: 10_000},
        mb: [
          tx:
            oracle_register_tx(:alice, %{
              query_format: <<195, 161>>,
              response_format: <<195, 159>>
            })
        ] do
        %{txs: [tx]} = blocks[:mb]

        {:id, :account, alice_pk} = accounts[:alice]
        alice_id = encode(:account_pubkey, alice_pk)
        oracle_id = encode(:oracle_pubkey, alice_pk)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {0, 0}, id: :aetx_sign.hash(tx)))
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 2))

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx))

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "account_id" => ^alice_id,
                   "oracle_id" => ^oracle_id,
                   "query_format" => "á",
                   "response_format" => "ß"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{tx_hash}")
                 |> json_response(200)
      end
    end
  end

  describe "count" do
    test "it returns all tx count by default", %{conn: conn, store: store} do
      tx = Model.tx(index: tx_index) = TS.tx(0)
      store = Store.put(store, Model.Tx, tx)

      assert ^tx_index =
               conn
               |> with_store(store)
               |> get("/txs/count")
               |> json_response(200)
    end

    test "it returns the difference between first and last txi", %{conn: conn} do
      first_txi = 600
      last_txi = 500

      assert 101 =
               conn
               |> get("/txs/count", scope: "txi:#{first_txi}-#{last_txi}")
               |> json_response(200)
    end

    test "when filtering by type, it displays type_count number", %{conn: conn, store: store} do
      count = 102

      store =
        Store.put(
          store,
          Model.TypeCount,
          Model.type_count(index: :oracle_register_tx, count: count)
        )

      assert ^count =
               conn
               |> with_store(store)
               |> get("/txs/count", type: "oracle_register")
               |> json_response(200)
    end

    test "when filtering by id, it displays the total count for that address", %{
      conn: conn,
      store: store
    } do
      address = TS.address(0)
      enc_address = :aeser_api_encoder.encode(:account_pubkey, address)

      store =
        store
        |> Store.put(Model.IdCount, Model.id_count(index: {:spend_tx, 1, address}, count: 3))
        |> Store.put(Model.IdCount, Model.id_count(index: {:spend_tx, 2, address}, count: 2))
        |> Store.put(
          Model.IdCount,
          Model.id_count(index: {:oracle_extend_tx, 1, address}, count: 10)
        )

      assert 15 =
               conn
               |> with_store(store)
               |> get("/txs/count", id: enc_address)
               |> json_response(200)
    end

    test "when filtering by invalid type, it displays an error", %{conn: conn} do
      error_msg = "invalid transaction type: oracle_foo"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/txs/count", type: "oracle_foo")
               |> json_response(400)
    end
  end

  describe "micro_block_txs" do
    test "it returns the list of txs from a single mb by mb_hash", %{conn: conn, store: store} do
      mb_hash = TS.micro_block_hash(0)
      tx1_hash = TS.tx_hash(0)
      tx2_hash = TS.tx_hash(1)
      encoded_mb_hash = encode(:micro_block_hash, mb_hash)
      height = 4

      store =
        store
        |> Store.put(Model.Block, Model.block(index: {height, -1}, tx_index: 10))
        |> Store.put(Model.Block, Model.block(index: {height, 0}, tx_index: 10))
        |> Store.put(Model.Block, Model.block(index: {height + 1, -1}, tx_index: 12))
        |> Store.put(Model.Tx, Model.tx(index: 10, id: tx1_hash))
        |> Store.put(Model.Tx, Model.tx(index: 11, id: tx2_hash))

      with_mocks [
        {:aec_chain, [], [get_block: fn ^mb_hash -> {:ok, :block} end]},
        {:aec_blocks, [], [to_header: fn :block -> :header end]},
        {:aec_headers, [],
         [
           type: fn :header -> :micro end,
           height: fn :header -> height end
         ]},
        {Db, [], [get_reverse_micro_blocks: fn ^mb_hash -> [] end]},
        {Format, [],
         [
           to_map: fn
             _state, Model.tx(id: ^tx1_hash) -> %{a: 1}
             _state, Model.tx(id: ^tx2_hash) -> %{b: 2}
           end
         ]}
      ] do
        assert %{"data" => [tx2, tx1]} =
                 conn
                 |> with_store(store)
                 |> get("/v2/micro-blocks/#{encoded_mb_hash}/txs")
                 |> json_response(200)

        assert %{"a" => 1} = tx1
        assert %{"b" => 2} = tx2
      end
    end

    test "when it's the last micro block, it returns the list of txs from it till the end", %{
      conn: conn,
      store: store
    } do
      mb_hash = TS.micro_block_hash(0)
      tx1_hash = TS.tx_hash(0)
      tx2_hash = TS.tx_hash(1)
      encoded_mb_hash = encode(:micro_block_hash, mb_hash)
      height = 4

      store =
        store
        |> Store.put(Model.Block, Model.block(index: {height, -1}, tx_index: 10))
        |> Store.put(Model.Block, Model.block(index: {height, 0}, tx_index: 10))
        |> Store.put(Model.Tx, Model.tx(index: 10, id: tx1_hash))
        |> Store.put(Model.Tx, Model.tx(index: 11, id: tx2_hash))

      with_mocks [
        {:aec_chain, [], [get_block: fn ^mb_hash -> {:ok, :block} end]},
        {:aec_blocks, [], [to_header: fn :block -> :header end]},
        {:aec_headers, [],
         [
           type: fn :header -> :micro end,
           height: fn :header -> height end
         ]},
        {Db, [], [get_reverse_micro_blocks: fn ^mb_hash -> [] end]},
        {Format, [],
         [
           to_map: fn
             _state, Model.tx(id: ^tx1_hash) -> %{a: 1}
             _state, Model.tx(id: ^tx2_hash) -> %{b: 2}
           end
         ]}
      ] do
        assert %{"data" => [tx2, tx1]} =
                 conn
                 |> with_store(store)
                 |> get("/v2/micro-blocks/#{encoded_mb_hash}/txs")
                 |> json_response(200)

        assert %{"a" => 1} = tx1
        assert %{"b" => 2} = tx2
      end
    end

    test "if no txs, it returns an empty result", %{conn: conn, store: store} do
      mb_hash = TS.micro_block_hash(0)
      encoded_mb_hash = encode(:micro_block_hash, mb_hash)
      error_msg = "not found: #{encoded_mb_hash}"

      store = Store.put(store, Model.Block, Model.block(index: {3, 0}, tx_index: 10))

      with_mocks [
        {:aec_chain, [], [get_block: fn ^mb_hash -> :error end]}
      ] do
        assert %{"error" => ^error_msg} =
                 conn
                 |> with_store(store)
                 |> get("/v2/micro-blocks/#{encoded_mb_hash}/txs")
                 |> json_response(404)
      end
    end
  end

  defp encode(type, bin), do: :aeser_api_encoder.encode(type, bin)
end
