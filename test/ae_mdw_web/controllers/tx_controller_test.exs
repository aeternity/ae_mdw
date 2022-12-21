defmodule AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.Util
  alias AeMdw.Node.Db
  alias AeMdw.TestSamples, as: TS

  import AeMdwWeb.BlockchainSim,
    only: [with_blockchain: 3, tx: 3, spend_tx: 3, name_tx: 3, name_tx: 4]

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

    test "returns an ga_attach_tx with call details", %{
      conn: conn,
      store: store
    } do
      nonce = 3

      call_data =
        <<43, 17, 68, 214, 68, 31, 27, 159, 1, 81, 36, 174, 134, 247, 199, 24, 36, 209, 93, 111,
          71, 91, 175, 20, 235, 201, 171, 175, 148, 138>>

      with_blockchain %{ga: 10_000},
        mb: [
          ga_tx:
            tx(:ga_attach_tx, :ga, %{
              nonce: nonce,
              call_data: call_data,
              auth_fun: <<108, 242, 87, 11>> <> <<0::112>>
            })
        ] do
        %{txs: [signed_tx]} = blocks[:mb]
        {:id, :account, account_pk} = accounts[:ga]
        account_id = encode(:account_pubkey, account_pk)
        mb_hash = :crypto.strong_rand_bytes(32)

        store =
          store
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1, block_index: {0, 0}, id: :aetx_sign.hash(signed_tx))
          )
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, hash: mb_hash, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 2))

        functions = %{
          <<68, 214, 68, 31>> =>
            {[], {[bytes: 20], {:tuple, []}},
             %{
               0 => [
                 {:STORE, {:var, -1}, {:immediate, 1}},
                 {:STORE, {:var, -2}, {:arg, 0}},
                 {:RETURNR, {:immediate, {:tuple, {}}}}
               ]
             }}
        }

        type_info =
          {:fcode, functions,
           %{<<68, 214, 68, 31>> => "init", <<108, 242, 87, 11>> => "authorize"}, nil}

        {_mod, tx} = signed_tx |> :aetx_sign.tx() |> :aetx.specialize_callback()
        contract_pk = :aega_attach_tx.contract_pubkey(tx)

        AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

        tx_hash = encode(:tx_hash, :aetx_sign.hash(signed_tx))

        {:tuple, {_fun_hash, {:tuple, {{:bytes, arg_bytes}}}}} =
          :aeb_fate_encoding.deserialize(call_data)

        bytes_arg = encode(:bytearray, arg_bytes)

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "auth_fun_name" => "authorize",
                   "nonce" => ^nonce,
                   "owner_id" => ^account_id,
                   "args" => [%{"type" => "bytes", "value" => ^bytes_arg}],
                   "gas_used" => 1_000,
                   "return_type" => "ok",
                   "type" => "GAAttachTx"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{tx_hash}")
                 |> json_response(200)
      end
    end

    test "returns an ga_meta_tx with return_type and pointers", %{
      conn: conn,
      store: store
    } do
      name = "binarypointer.chain"
      {:ok, name_hash} = :aens.get_name_hash(name)
      pointer_id = :aeser_id.create(:account, <<1::256>>)
      oracle_id = :aeser_id.create(:oracle, <<2::256>>)
      name_account_id = :aeser_id.create(:account, <<3::256>>)

      non_string_pointer_key =
        <<96, 70, 239, 88, 30, 239, 116, 157, 73, 35, 96, 177, 84, 44, 123, 233, 151, 181, 221,
          202, 13, 46, 81, 10, 67, 18, 178, 23, 153, 139, 252, 116>>

      non_string_pointer_key64 = Base.encode64(non_string_pointer_key)

      {:ok, name_update_tx} =
        :aens_update_tx.new(%{
          account_id: name_account_id,
          nonce: 1,
          name_id: :aeser_id.create(:name, name_hash),
          name_ttl: 1_000,
          pointers: [
            {:pointer, non_string_pointer_key, pointer_id},
            {:pointer, "oracle_pubkey", oracle_id}
          ],
          client_ttl: 1_000,
          fee: 5_000
        })

      pointer_id = encode_account(<<1::256>>)
      oracle_id = encode(:oracle_pubkey, <<2::256>>)
      name_account_id = encode_account(<<3::256>>)
      name_id = encode(:name, name_hash)

      with_blockchain %{ga: 10_000},
        mb: [
          ga_tx: tx(:ga_meta_tx, :ga, %{tx: :aetx_sign.new(name_update_tx, [])})
        ] do
        %{txs: [tx]} = blocks[:mb]
        {:id, :account, account_pk} = accounts[:ga]
        ga_id = encode(:account_pubkey, account_pk)
        mb_hash = :crypto.strong_rand_bytes(32)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {0, 0}, id: :aetx_sign.hash(tx)))
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, hash: mb_hash, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 2))

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx))

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "ga_id" => ^ga_id,
                   "gas_used" => 2_000,
                   "return_type" => "ok",
                   "tx" => %{
                     "tx" => %{
                       "account_id" => ^name_account_id,
                       "client_ttl" => 1000,
                       "fee" => 5000,
                       "name_id" => ^name_id,
                       "name_ttl" => 1000,
                       "nonce" => 1,
                       "pointers" => [
                         %{"key" => ^non_string_pointer_key64, "id" => ^pointer_id},
                         %{"key" => "oracle_pubkey", "id" => ^oracle_id}
                       ],
                       "type" => "NameUpdateTx",
                       "version" => 1
                     }
                   },
                   "type" => "GAMetaTx"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{tx_hash}")
                 |> json_response(200)
      end
    end

    test "returns an oracle_register_tx with non-string format fields", %{
      conn: conn,
      store: store
    } do
      with_blockchain %{alice: 10_000},
        mb: [
          tx:
            tx(:oracle_register_tx, :alice, %{query_format: <<0, 160>>, response_format: <<225>>})
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
            tx(:oracle_register_tx, :alice, %{
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

    test "returns a spend_tx with inactive name recipient", %{conn: conn, store: store} do
      plain_name = "aliceinchains.chain"
      {:ok, name_hash} = :aens.get_name_hash(plain_name)

      with_blockchain %{alice: 10_000, auctioneer: 10_000},
        mb: [
          tx1: name_tx(:name_update_tx, :alice, plain_name),
          tx2: spend_tx(:auctioneer, {:id, :name, name_hash}, 5_000)
        ] do
        %{txs: [tx1, tx2]} = blocks[:mb]

        {:id, :account, sender_pk} = accounts[:auctioneer]
        {:id, :account, alice_pk} = accounts[:alice]
        sender_id = encode(:account_pubkey, sender_pk)
        alice_id = encode(:account_pubkey, alice_pk)

        store =
          store
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1, block_index: {0, 0}, id: :aetx_sign.hash(tx1))
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 2, block_index: {0, 0}, id: :aetx_sign.hash(tx2))
          )
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
          |> Store.put(Model.InactiveName, Model.name(index: plain_name, updates: [{{0, 0}, 1}]))
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 2))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 3))

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx2))
        recipient_id = encode(:name, name_hash)

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "amount" => 5_000,
                   "sender_id" => ^sender_id,
                   "recipient_id" => ^recipient_id,
                   "recipient" => %{
                     "name" => ^plain_name,
                     "account" => ^alice_id
                   }
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{tx_hash}")
                 |> json_response(200)
      end
    end

    test "returns a name_update_tx with multiple pointers", %{conn: conn, store: store} do
      plain_name = "aliceinchains.chain"
      {:ok, name_hash} = :aens.get_name_hash(plain_name)

      with_blockchain %{alice: 10_000},
        mb: [
          tx: name_tx(:name_update_tx, :alice, plain_name)
        ] do
        %{txs: [tx]} = blocks[:mb]

        {:id, :account, alice_pk} = accounts[:alice]
        alice_id = encode(:account_pubkey, alice_pk)
        oracle_id = encode(:oracle_pubkey, alice_pk)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {0, 0}, id: :aetx_sign.hash(tx)))
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
          |> Store.put(Model.ActiveName, Model.name(index: plain_name))
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 2))

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx))

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "account_id" => ^alice_id,
                   "name" => ^plain_name,
                   "pointers" => [
                     %{
                       "id" => ^alice_id,
                       "key" => "account_pubkey"
                     },
                     %{
                       "id" => ^oracle_id,
                       "key" => "oracle_pubkey"
                     }
                   ]
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{tx_hash}")
                 |> json_response(200)
      end
    end

    test "returns a name_update_tx with non-string pointers", %{conn: conn, store: store} do
      plain_name = "aliceinchains.chain"
      {:ok, name_hash} = :aens.get_name_hash(plain_name)

      non_string_pointer_key =
        <<104, 65, 117, 174, 49, 251, 29, 202, 69, 174, 147, 56, 60, 150, 188, 247, 149, 85, 150,
          148, 88, 102, 186, 208, 87, 101, 78, 111, 189, 5, 144, 101>>

      non_string_pointer_key64 = Base.encode64(non_string_pointer_key)

      with_blockchain %{alice1: 1_000, alice2: 1_000},
        mb: [
          tx:
            name_tx(:name_update_tx, :alice1, plain_name, %{
              pointers: [{:pointer, non_string_pointer_key, :alice2}]
            })
        ] do
        %{txs: [tx]} = blocks[:mb]
        {:id, :account, alice_pk1} = accounts[:alice1]
        {:id, :account, alice_pk2} = accounts[:alice2]
        alice_id1 = encode(:account_pubkey, alice_pk1)
        alice_id2 = encode(:account_pubkey, alice_pk2)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {0, 0}, id: :aetx_sign.hash(tx)))
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
          |> Store.put(Model.ActiveName, Model.name(index: plain_name))
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 2))

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx))

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "account_id" => ^alice_id1,
                   "name" => ^plain_name,
                   "pointers" => [
                     %{
                       "id" => ^alice_id2,
                       "key" => ^non_string_pointer_key64
                     }
                   ]
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

    test "when filtering by tx_type, it displays type_count number", %{conn: conn, store: store} do
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
               |> get("/txs/count", tx_type: "oracle_register")
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

    test "if mb exists on node but doesn't exist on mdw, it returns 404", %{
      conn: conn,
      store: store
    } do
      mb_hash = TS.micro_block_hash(0)
      encoded_mb_hash = encode(:micro_block_hash, mb_hash)
      error_msg = "not found: #{encoded_mb_hash}"

      store = Store.put(store, Model.Block, Model.block(index: {3, 0}, tx_index: 10))

      with_mocks [
        {:aec_chain, [], [get_block: fn ^mb_hash -> {:ok, :block} end]},
        {:aec_blocks, [], [to_header: fn :block -> :header end]},
        {:aec_headers, [],
         [
           type: fn :header -> :micro end,
           height: fn :header -> 1 end
         ]},
        {Db, [], [get_reverse_micro_blocks: fn ^mb_hash -> [] end]}
      ] do
        assert %{"error" => ^error_msg} =
                 conn
                 |> with_store(store)
                 |> get("/v2/micro-blocks/#{encoded_mb_hash}/txs")
                 |> json_response(404)
      end
    end
  end
end
