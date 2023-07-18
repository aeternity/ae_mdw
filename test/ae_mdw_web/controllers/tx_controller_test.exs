defmodule AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.DryRun.Contract
  alias AeMdw.Node.Db
  alias AeMdw.TestSamples, as: TS

  import AeMdwWeb.BlockchainSim,
    only: [with_blockchain: 3, tx: 3, spend_tx: 3, name_tx: 3, name_tx: 4]

  import Mock

  require Model

  describe "txs" do
    test "it returns 400 when no direction specified", %{conn: conn} do
      assert %{"error" => "no such route"} = conn |> get("/txs") |> json_response(404)
    end
  end

  describe "/v2/txs" do
    test "it filters by type", %{conn: conn, store: store} do
      with_blockchain %{alice: 10_000, bob: 20_000},
        mb1: [
          tx1: tx(:oracle_register_tx, :alice, %{}),
          tx2: tx(:oracle_register_tx, :bob, %{}),
          tx3: spend_tx(:alice, :bob, 3_000)
        ] do
        %{txs: [signed_tx1, signed_tx2, _signed_tx3]} = blocks[:mb1]
        tx_hash1 = :aetx_sign.hash(signed_tx1)
        encoded_tx_hash1 = Enc.encode(:tx_hash, tx_hash1)
        tx_hash2 = :aetx_sign.hash(signed_tx2)
        encoded_tx_hash2 = Enc.encode(:tx_hash, tx_hash2)

        store =
          store
          |> Store.put(Model.Type, Model.type(index: {:oracle_register_tx, 1}))
          |> Store.put(Model.Tx, Model.tx(index: 1, id: tx_hash1))
          |> Store.put(Model.Type, Model.type(index: {:oracle_register_tx, 2}))
          |> Store.put(Model.Tx, Model.tx(index: 2, id: tx_hash2))
          |> Store.put(Model.Type, Model.type(index: {:spend_tx, 3}))

        assert %{"data" => [tx1], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs", type: "oracle_register", limit: 1, direction: "forward")
                 |> json_response(200)

        assert %{
                 "tx" => %{"type" => "OracleRegisterTx"},
                 "hash" => ^encoded_tx_hash1
               } = tx1

        assert %{"data" => [tx2], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        assert %{
                 "tx" => %{"type" => "OracleRegisterTx"},
                 "hash" => ^encoded_tx_hash2
               } = tx2
      end
    end

    test "it filters by id", %{conn: conn, store: store} do
      oracle_pk = TS.address(1)
      oracle_id = :aeser_id.create(:oracle, oracle_pk)
      encoded_oracle_id = Enc.encode(:oracle_pubkey, oracle_pk)
      txi1 = 123
      txi2 = 124
      txi3 = 125

      with_blockchain %{alice: 10_000},
        mb1: [
          tx1: {:oracle_query_tx, :alice, oracle_id, %{}},
          tx2: {:oracle_query_tx, :alice, oracle_id, %{}},
          tx3: spend_tx(:alice, :alice, 3_000)
        ] do
        %{txs: [signed_tx1, signed_tx2, signed_tx3]} = blocks[:mb1]
        alice_id = accounts[:alice]
        {:account, alice_pk} = :aeser_id.specialize(alice_id)
        alice_encoded_id = Enc.encode(:account_pubkey, alice_pk)

        tx_hash1 = :aetx_sign.hash(signed_tx1)
        encoded_tx_hash1 = Enc.encode(:tx_hash, tx_hash1)
        tx_hash2 = :aetx_sign.hash(signed_tx2)
        encoded_tx_hash2 = Enc.encode(:tx_hash, tx_hash2)
        tx_hash3 = :aetx_sign.hash(signed_tx3)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: txi1, id: tx_hash1))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 1, alice_pk, txi1}))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 3, oracle_pk, txi1}))
          |> Store.put(Model.Tx, Model.tx(index: txi2, id: tx_hash2))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 1, alice_pk, txi2}))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 3, oracle_pk, txi2}))
          |> Store.put(Model.Tx, Model.tx(index: txi3, id: tx_hash3))
          |> Store.put(Model.Field, Model.field(index: {:spend_tx, 1, alice_pk, txi3}))

        assert %{"data" => [tx1], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs",
                   type: "oracle_query",
                   oracle: encoded_oracle_id,
                   direction: "forward",
                   limit: 1
                 )
                 |> json_response(200)

        assert %{
                 "tx" => %{
                   "type" => "OracleQueryTx",
                   "oracle_id" => ^encoded_oracle_id,
                   "sender_id" => ^alice_encoded_id
                 },
                 "hash" => ^encoded_tx_hash1
               } = tx1

        assert %{"data" => [tx2], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        assert %{
                 "tx" => %{
                   "type" => "OracleQueryTx",
                   "oracle_id" => ^encoded_oracle_id,
                   "sender_id" => ^alice_encoded_id
                 },
                 "hash" => ^encoded_tx_hash2
               } = tx2
      end
    end

    test "it filters by type and scope", %{conn: conn, store: store} do
      first_gen = 10
      last_gen = 20

      with_blockchain %{alice: 10_000, bob: 20_000},
        mb1: [
          tx1: tx(:oracle_register_tx, :alice, %{}),
          tx2: tx(:oracle_register_tx, :bob, %{}),
          tx3: spend_tx(:alice, :bob, 3_000)
        ] do
        %{txs: [signed_tx1, _signed_tx2, _signed_tx3]} = blocks[:mb1]
        tx_hash1 = :aetx_sign.hash(signed_tx1)
        encoded_tx_hash1 = Enc.encode(:tx_hash, tx_hash1)

        store =
          store
          |> Store.put(Model.Type, Model.type(index: {:oracle_register_tx, 1}))
          |> Store.put(Model.Tx, Model.tx(index: 1, id: tx_hash1))
          |> Store.put(Model.Block, Model.block(index: {first_gen, -1}, tx_index: 1))
          |> Store.put(Model.Type, Model.type(index: {:oracle_register_tx, 2}))
          |> Store.put(Model.Type, Model.type(index: {:spend_tx, 3}))
          |> Store.put(Model.Block, Model.block(index: {last_gen + 1, -1}, tx_index: 2))

        assert %{"data" => [tx1], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs",
                   type: "oracle_register",
                   scope: "gen:#{first_gen}-#{last_gen}",
                   direction: "forward"
                 )
                 |> json_response(200)

        assert %{
                 "tx" => %{"type" => "OracleRegisterTx"},
                 "hash" => ^encoded_tx_hash1
               } = tx1
      end
    end

    test "it filters by id and type", %{conn: conn, store: store} do
      oracle_pk = TS.address(1)
      oracle_id = :aeser_id.create(:oracle, oracle_pk)
      encoded_oracle_id = Enc.encode(:oracle_pubkey, oracle_pk)
      txi1 = 123
      txi2 = 124
      txi3 = 125

      with_blockchain %{alice: 10_000},
        mb1: [
          tx1: {:oracle_query_tx, :alice, oracle_id, %{}},
          tx2: {:oracle_query_tx, :alice, oracle_id, %{}},
          tx3: spend_tx(:alice, :alice, 3_000)
        ] do
        %{txs: [signed_tx1, signed_tx2, signed_tx3]} = blocks[:mb1]
        alice_id = accounts[:alice]
        {:account, alice_pk} = :aeser_id.specialize(alice_id)
        alice_encoded_id = Enc.encode(:account_pubkey, alice_pk)

        tx_hash1 = :aetx_sign.hash(signed_tx1)
        encoded_tx_hash1 = Enc.encode(:tx_hash, tx_hash1)
        tx_hash2 = :aetx_sign.hash(signed_tx2)
        encoded_tx_hash2 = Enc.encode(:tx_hash, tx_hash2)
        tx_hash3 = :aetx_sign.hash(signed_tx3)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: txi1, id: tx_hash1))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 1, alice_pk, txi1}))
          |> Store.put(Model.Tx, Model.tx(index: txi2, id: tx_hash2))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 1, alice_pk, txi2}))
          |> Store.put(Model.Tx, Model.tx(index: txi3, id: tx_hash3))
          |> Store.put(Model.Field, Model.field(index: {:spend_tx, 1, alice_pk, txi3}))

        assert %{"data" => [tx1], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs",
                   type: "oracle_query",
                   sender_id: alice_encoded_id,
                   direction: "forward",
                   limit: 1
                 )
                 |> json_response(200)

        assert %{
                 "tx" => %{
                   "type" => "OracleQueryTx",
                   "oracle_id" => ^encoded_oracle_id,
                   "sender_id" => ^alice_encoded_id
                 },
                 "hash" => ^encoded_tx_hash1
               } = tx1

        assert %{"data" => [tx2], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        assert %{
                 "tx" => %{
                   "type" => "OracleQueryTx",
                   "oracle_id" => ^encoded_oracle_id,
                   "sender_id" => ^alice_encoded_id
                 },
                 "hash" => ^encoded_tx_hash2
               } = tx2
      end
    end

    test "when filtering by multiple ids, it returns the intersection", %{
      conn: conn,
      store: store
    } do
      oracle_pk = TS.address(1)
      oracle_id = :aeser_id.create(:oracle, oracle_pk)
      txi1 = 123
      txi2 = 124
      txi3 = 125

      with_blockchain %{alice: 10_000, bob: 20_000},
        mb1: [
          tx1: {:oracle_query_tx, :alice, oracle_id, %{}},
          tx2: {:oracle_query_tx, :alice, oracle_id, %{}},
          tx3: spend_tx(:alice, :bob, 3_000)
        ] do
        %{txs: [signed_tx1, signed_tx2, signed_tx3]} = blocks[:mb1]
        alice_id = accounts[:alice]
        {:account, alice_pk} = :aeser_id.specialize(alice_id)
        encoded_alice_id = Enc.encode(:account_pubkey, alice_pk)
        bob_id = accounts[:bob]
        {:account, bob_pk} = :aeser_id.specialize(bob_id)
        encoded_bob_id = Enc.encode(:account_pubkey, bob_pk)

        tx_hash1 = :aetx_sign.hash(signed_tx1)
        tx_hash2 = :aetx_sign.hash(signed_tx2)
        tx_hash3 = :aetx_sign.hash(signed_tx3)
        encoded_tx_hash3 = Enc.encode(:tx_hash, tx_hash3)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: txi1, id: tx_hash1))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 1, alice_pk, txi1}))
          |> Store.put(Model.Tx, Model.tx(index: txi2, id: tx_hash2))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 1, alice_pk, txi2}))
          |> Store.put(Model.Tx, Model.tx(index: txi3, id: tx_hash3))
          |> Store.put(Model.Field, Model.field(index: {:spend_tx, 1, alice_pk, txi3}))
          |> Store.put(Model.Field, Model.field(index: {:spend_tx, 2, bob_pk, txi3}))

        assert %{"data" => [tx1], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs",
                   sender_id: encoded_alice_id,
                   recipient_id: encoded_bob_id,
                   limit: 1
                 )
                 |> json_response(200)

        assert %{
                 "tx" => %{
                   "type" => "SpendTx",
                   "sender_id" => ^encoded_alice_id,
                   "recipient_id" => ^encoded_bob_id
                 },
                 "hash" => ^encoded_tx_hash3
               } = tx1
      end
    end

    test "it filters by id, type and scope", %{conn: conn, store: store} do
      oracle_pk = TS.address(1)
      oracle_id = :aeser_id.create(:oracle, oracle_pk)
      encoded_oracle_id = Enc.encode(:oracle_pubkey, oracle_pk)
      txi1 = 123
      txi2 = 124
      txi3 = 125
      first_gen = 456
      last_gen = 457

      with_blockchain %{alice: 10_000},
        mb1: [
          tx1: {:oracle_query_tx, :alice, oracle_id, %{}},
          tx2: {:oracle_query_tx, :alice, oracle_id, %{}},
          tx3: spend_tx(:alice, :alice, 3_000)
        ] do
        %{txs: [signed_tx1, signed_tx2, signed_tx3]} = blocks[:mb1]
        alice_id = accounts[:alice]
        {:account, alice_pk} = :aeser_id.specialize(alice_id)
        alice_encoded_id = Enc.encode(:account_pubkey, alice_pk)
        tx_hash1 = :aetx_sign.hash(signed_tx1)
        encoded_tx_hash1 = Enc.encode(:tx_hash, tx_hash1)
        tx_hash2 = :aetx_sign.hash(signed_tx2)
        tx_hash3 = :aetx_sign.hash(signed_tx3)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: txi1, id: tx_hash1))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 1, alice_pk, txi1}))
          |> Store.put(Model.Tx, Model.tx(index: txi2, id: tx_hash2))
          |> Store.put(Model.Block, Model.block(index: {first_gen, -1}, tx_index: txi1))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 1, alice_pk, txi2}))
          |> Store.put(Model.Tx, Model.tx(index: txi3, id: tx_hash3))
          |> Store.put(Model.Field, Model.field(index: {:spend_tx, 1, alice_pk, txi3}))
          |> Store.put(Model.Block, Model.block(index: {last_gen + 1, -1}, tx_index: txi2))

        assert %{"data" => [tx1], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs",
                   type: "oracle_query",
                   sender_id: alice_encoded_id,
                   scope: "gen:#{first_gen}-#{last_gen}",
                   limit: 1
                 )
                 |> json_response(200)

        assert %{
                 "tx" => %{
                   "type" => "OracleQueryTx",
                   "oracle_id" => ^encoded_oracle_id,
                   "sender_id" => ^alice_encoded_id
                 },
                 "hash" => ^encoded_tx_hash1
               } = tx1
      end
    end

    test "it filters by field", %{conn: conn, store: store} do
      TODO
      oracle_pk = TS.address(1)
      oracle_id = :aeser_id.create(:oracle, oracle_pk)
      txi1 = 123
      txi2 = 124
      txi3 = 125
      first_gen = 456
      last_gen = 457

      with_blockchain %{alice: 10_000},
        mb1: [
          tx1: {:oracle_query_tx, :alice, oracle_id, %{}},
          tx2: {:oracle_query_tx, :alice, oracle_id, %{}},
          tx3: spend_tx(:alice, :alice, 3_000)
        ] do
        %{txs: [signed_tx1, signed_tx2, signed_tx3]} = blocks[:mb1]
        alice_id = accounts[:alice]
        {:account, alice_pk} = :aeser_id.specialize(alice_id)
        alice_encoded_id = Enc.encode(:account_pubkey, alice_pk)
        tx_hash1 = :aetx_sign.hash(signed_tx1)
        tx_hash2 = :aetx_sign.hash(signed_tx2)
        tx_hash3 = :aetx_sign.hash(signed_tx3)
        encoded_tx_hash3 = Enc.encode(:tx_hash, tx_hash3)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: txi1, id: tx_hash1))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 1, alice_pk, txi1}))
          |> Store.put(Model.Tx, Model.tx(index: txi2, id: tx_hash2))
          |> Store.put(Model.Block, Model.block(index: {first_gen, -1}, tx_index: txi1))
          |> Store.put(Model.Field, Model.field(index: {:oracle_query_tx, 1, alice_pk, txi2}))
          |> Store.put(Model.Tx, Model.tx(index: txi3, id: tx_hash3))
          |> Store.put(Model.Field, Model.field(index: {:spend_tx, 1, alice_pk, txi3}))
          |> Store.put(Model.Block, Model.block(index: {last_gen + 1, -1}, tx_index: txi2))
          |> Store.put(Model.IdCount, Model.id_count(index: {:spend_tx, 1, alice_pk}, count: 1))

        assert %{"data" => [tx1], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get(
                   "/v2/txs",
                   [{"spend.sender_id", alice_encoded_id}, {:limit, 1}]
                 )
                 |> json_response(200)

        assert %{
                 "tx" => %{"type" => "SpendTx", "sender_id" => ^alice_encoded_id},
                 "hash" => ^encoded_tx_hash3
               } = tx1
      end
    end

    test "when filtering by an invalid field, it returns an error", %{conn: conn, store: store} do
      account_pk = TS.address(0)
      encoded_account = Enc.encode(:account_pubkey, account_pk)

      assert %{"error" => "invalid transaction field: :foo_id"} =
               conn
               |> with_store(store)
               |> get("/v2/txs", foo_id: encoded_account)
               |> json_response(400)

      assert %{"error" => "invalid transaction type: foo"} =
               conn
               |> with_store(store)
               |> get("/v2/txs", [{"foo.recipient_id", encoded_account}])
               |> json_response(400)

      assert %{"error" => "invalid transaction field: :spend"} =
               conn
               |> with_store(store)
               |> get("/v2/txs", [{"spend.foo_id", encoded_account}])
               |> json_response(400)

      assert %{"error" => "invalid transaction field: :oracle_id"} =
               conn
               |> with_store(store)
               |> get("/v2/txs", [{"spend.oracle_id", encoded_account}])
               |> json_response(400)

      assert %{"error" => "invalid transaction field: :spend.recipient_id.sender_id"} =
               conn
               |> with_store(store)
               |> get("/v2/txs", [{"spend.recipient_id.sender_id", encoded_account}])
               |> json_response(400)
    end

    test "when filtering by an invalid id, it returns an error", %{conn: conn, store: store} do
      error_msg = "invalid id: foo"

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v2/txs", recipient_id: "foo")
               |> json_response(400)
    end
  end

  describe "tx" do
    test "returns 404 when tx location is not a block hash", %{conn: conn} do
      tx_hash1 = :crypto.strong_rand_bytes(32)
      tx_hash2 = :crypto.strong_rand_bytes(32)
      tx_hash3 = :crypto.strong_rand_bytes(32)
      tx_hash4 = :crypto.strong_rand_bytes(32)
      enc_tx_hash1 = encode(:tx_hash, tx_hash1)
      enc_tx_hash2 = encode(:tx_hash, tx_hash2)
      enc_tx_hash3 = encode(:tx_hash, tx_hash3)
      enc_tx_hash4 = encode(:tx_hash, tx_hash4)
      mb_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {:aec_db, [:passthrough],
         [
           find_tx_location: fn
             ^tx_hash1 -> :none
             ^tx_hash2 -> :not_found
             ^tx_hash3 -> :mempool
             ^tx_hash4 -> mb_hash
           end
         ]},
        {:aec_chain, [], [get_header: fn ^mb_hash -> {:ok, :header} end]},
        {:aec_headers, [], [height: fn :header -> 1 end]}
      ] do
        assert %{"error" => _error_msg} = conn |> get("/tx/#{enc_tx_hash1}") |> json_response(404)
        assert %{"error" => _error_msg} = conn |> get("/tx/#{enc_tx_hash2}") |> json_response(404)
        assert %{"error" => _error_msg} = conn |> get("/tx/#{enc_tx_hash3}") |> json_response(404)

        assert %{"error" => <<"not found: ", ^enc_tx_hash4::binary>>} =
                 conn |> get("/tx/#{enc_tx_hash4}") |> json_response(404)
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
        account_pk = :aeser_id.specialize(accounts[:ga], :account)
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
                   "gas_used" => 0,
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
      plain_name = "binarypointer.chain"
      {:ok, name_hash} = :aens.get_name_hash(plain_name)
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
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))

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

    test "returns a paying_for with name_update_tx having binary pointer", %{
      conn: conn,
      store: store
    } do
      plain_name = "binarypointer.chain"
      {:ok, name_hash} = :aens.get_name_hash(plain_name)
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

      with_blockchain %{pf: 10_000},
        mb: [
          pf_tx: tx(:paying_for_tx, :pf, %{tx: :aetx_sign.new(name_update_tx, [])})
        ] do
        %{txs: [tx]} = blocks[:mb]
        {:id, :account, account_pk} = accounts[:pf]
        payer_id = encode(:account_pubkey, account_pk)
        mb_hash = :crypto.strong_rand_bytes(32)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {0, 0}, id: :aetx_sign.hash(tx)))
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, hash: mb_hash, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 2))
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx))

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "payer_id" => ^payer_id,
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
                   "type" => "PayingForTx"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{tx_hash}")
                 |> json_response(200)
      end
    end

    test "returns a paying_for with contract call details", %{
      conn: conn,
      store: store
    } do
      contract_pk = <<123::256>>
      function_name = "set_last_caller"
      args = [encode_account(<<1::256>>)]
      aetx = Contract.new_call_tx(:crypto.strong_rand_bytes(32), contract_pk, function_name, args)

      with_blockchain %{pf: 10_000},
        mb: [
          pf_tx: tx(:paying_for_tx, :pf, %{tx: :aetx_sign.new(aetx, [])})
        ] do
        %{txs: [tx]} = blocks[:mb]
        {:id, :account, account_pk} = accounts[:pf]
        payer_id = encode(:account_pubkey, account_pk)
        mb_hash = :crypto.strong_rand_bytes(32)

        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {0, 0}, id: :aetx_sign.hash(tx)))
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, hash: mb_hash, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 2))
          |> Store.put(
            Model.Field,
            Model.field(index: {:contract_create_tx, nil, contract_pk, 0})
          )
          |> Store.put(
            Model.ContractCall,
            Model.contract_call(
              index: {0, 1},
              fun: function_name,
              args: args,
              result: "ok",
              return: %{type: "unit", value: ""}
            )
          )

        {mod, contract_call_tx} = :aetx.specialize_callback(aetx)

        %{"call_data" => call_data, "contract_id" => contract_id} =
          mod.for_client(contract_call_tx)

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx))

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "payer_id" => ^payer_id,
                   "tx" => %{
                     "tx" => %{
                       "abi_version" => 3,
                       "amount" => 0,
                       "arguments" => ^args,
                       "call_data" => ^call_data,
                       "caller_id" => ^payer_id,
                       "contract_id" => ^contract_id,
                       "function" => "set_last_caller",
                       "log" => [],
                       "nonce" => 1,
                       "result" => "ok",
                       "return" => %{
                         "type" => "unit",
                         "value" => ""
                       },
                       "return_type" => "ok",
                       "type" => "ContractCallTx",
                       "version" => 1
                     }
                   },
                   "type" => "PayingForTx"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{tx_hash}")
                 |> json_response(200)
      end
    end

    test "returns a inner contract call filtered by entrypoint", %{
      conn: conn,
      store: store
    } do
      contract_pk = <<123::256>>
      function_name = "put_something"
      args = [encode_account(<<1::256>>)]
      aetx = Contract.new_call_tx(:crypto.strong_rand_bytes(32), contract_pk, function_name, args)

      with_blockchain %{pf: 10_000, bob: 5_000},
        mb: [
          pf_tx: tx(:paying_for_tx, :pf, %{tx: :aetx_sign.new(aetx, [])})
        ],
        mb2: [
          tx1: spend_tx(:pf, :bob, 1_000)
        ] do
        %{txs: [tx1]} = blocks[:mb]
        %{txs: [tx2]} = blocks[:mb2]
        {:id, :account, account_pk} = accounts[:pf]
        payer_id = encode(:account_pubkey, account_pk)
        mb_hash1 = :crypto.strong_rand_bytes(32)
        mb_hash2 = :crypto.strong_rand_bytes(32)

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
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, hash: mb_hash1, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 1}, hash: mb_hash2, tx_index: 2))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 3))
          |> Store.put(
            Model.Field,
            Model.field(index: {:contract_create_tx, nil, contract_pk, 0})
          )
          |> Store.put(
            Model.Field,
            Model.field(
              index:
                {:contract_call_tx, AeMdw.Fields.mdw_field_pos("entrypoint"), function_name, 1}
            )
          )
          |> Store.put(
            Model.ContractCall,
            Model.contract_call(
              index: {0, 1},
              fun: function_name,
              args: args,
              result: "ok",
              return: %{type: "unit", value: ""}
            )
          )

        {mod, contract_call_tx} = :aetx.specialize_callback(aetx)

        %{"call_data" => call_data, "contract_id" => contract_id} =
          mod.for_client(contract_call_tx)

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx1))

        assert %{"data" => [tx]} =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs", entrypoint: function_name)
                 |> json_response(200)

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "payer_id" => ^payer_id,
                   "tx" => %{
                     "tx" => %{
                       "abi_version" => 3,
                       "amount" => 0,
                       "arguments" => ^args,
                       "call_data" => ^call_data,
                       "caller_id" => ^payer_id,
                       "contract_id" => ^contract_id,
                       "function" => ^function_name,
                       "log" => [],
                       "nonce" => 1,
                       "result" => "ok",
                       "return" => %{
                         "type" => "unit",
                         "value" => ""
                       },
                       "return_type" => "ok",
                       "type" => "ContractCallTx",
                       "version" => 1
                     }
                   },
                   "type" => "PayingForTx"
                 }
               } = tx
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
      active_height = 123

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
          |> Store.put(
            Model.InactiveName,
            Model.name(index: plain_name, active: active_height)
          )
          |> Store.put(
            Model.NameUpdate,
            Model.name_update(index: {plain_name, active_height, {1, -1}})
          )
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

    test "returns a spend_tx with name recipient from previous", %{conn: conn, store: store} do
      plain_name1 = "aliceinchains1.chain"
      plain_name2 = "aliceinchains2.chain"
      {:ok, name_hash1} = :aens.get_name_hash(plain_name1)
      {:ok, name_hash2} = :aens.get_name_hash(plain_name2)
      active_height1 = 123
      active_height2 = 124

      with_blockchain %{alice: 10_000, bob: 10_000},
        mb: [
          tx1: name_tx(:name_update_tx, :alice, plain_name1),
          tx2: name_tx(:name_update_tx, :alice, plain_name2),
          tx3: spend_tx(:bob, {:id, :name, name_hash1}, 5_000),
          tx4: spend_tx(:bob, {:id, :name, name_hash2}, 5_000)
        ] do
        %{txs: [tx1, tx2, tx3, tx4]} = blocks[:mb]

        {:id, :account, sender_pk} = accounts[:bob]
        {:id, :account, alice_pk} = accounts[:alice]
        sender_id = encode(:account_pubkey, sender_pk)
        alice_id = encode(:account_pubkey, alice_pk)

        store =
          store
          |> Store.put(
            Model.Tx,
            Model.tx(index: 998, block_index: {0, 0}, id: :aetx_sign.hash(tx1))
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 999, block_index: {0, 0}, id: :aetx_sign.hash(tx2))
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1_000, block_index: {0, 0}, id: :aetx_sign.hash(tx3))
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1_001, block_index: {0, 0}, id: :aetx_sign.hash(tx4))
          )
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash1, value: plain_name1))
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash2, value: plain_name2))
          |> Store.put(
            Model.ActiveName,
            Model.name(
              index: plain_name1,
              previous: Model.name(index: plain_name1, active: active_height1)
            )
          )
          |> Store.put(
            Model.NameUpdate,
            Model.name_update(index: {plain_name1, active_height1, {998, -1}})
          )
          |> Store.put(
            Model.ActiveName,
            Model.name(
              index: plain_name2,
              previous: Model.name(index: plain_name2, active: active_height2)
            )
          )
          |> Store.put(
            Model.NameUpdate,
            Model.name_update(index: {plain_name2, active_height2, {999, -1}})
          )
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 998))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 998))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 998 + 4))

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx3))
        recipient_id = encode(:name, name_hash1)

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "amount" => 5_000,
                   "sender_id" => ^sender_id,
                   "recipient_id" => ^recipient_id,
                   "recipient" => %{
                     "name" => ^plain_name1,
                     "account" => ^alice_id
                   }
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{tx_hash}")
                 |> json_response(200)

        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx4))
        recipient_id = encode(:name, name_hash2)

        assert %{
                 "hash" => ^tx_hash,
                 "tx" => %{
                   "amount" => 5_000,
                   "sender_id" => ^sender_id,
                   "recipient_id" => ^recipient_id,
                   "recipient" => %{
                     "name" => ^plain_name2,
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

    test "returns channel participants and offchain tx round", %{conn: conn, store: store} do
      {initiator_pk1, responder_pk1} =
        {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32)}

      {initiator_pk2, responder_pk2} =
        {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32)}

      {initiator_pk3, responder_pk3} =
        {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32)}

      from_pk1 = :crypto.strong_rand_bytes(32)
      from_pk2 = :crypto.strong_rand_bytes(32)
      from_pk3 = :crypto.strong_rand_bytes(32)

      round1 = 10
      round2 = 20
      round3 = 30

      tx_hash1 = :crypto.strong_rand_bytes(32)
      tx_hash2 = :crypto.strong_rand_bytes(32)
      tx_hash3 = :crypto.strong_rand_bytes(32)

      poi = proof_of_inclusion([{<<3::256>>, 1_000}, {<<4::256>>, 2_000}])
      mb_hash = :crypto.strong_rand_bytes(32)
      mb_header = some_mb_header()

      {:ok, tx1} =
        :aesc_close_solo_tx.new(%{
          channel_id: :aeser_id.create(:channel, <<1::256>>),
          from_id: :aeser_id.create(:account, from_pk1),
          payload: channel_payload(round1),
          poi: poi,
          fee: 1,
          nonce: 1
        })

      {:ok, tx2} =
        :aesc_slash_tx.new(%{
          channel_id: :aeser_id.create(:channel, <<2::256>>),
          from_id: :aeser_id.create(:account, from_pk2),
          payload: channel_payload(round2),
          poi: poi,
          ttl: 1,
          fee: 1,
          nonce: 2
        })

      {:ok, tx3} =
        :aesc_snapshot_solo_tx.new(%{
          channel_id: :aeser_id.create(:channel, <<3::256>>),
          from_id: :aeser_id.create(:account, from_pk3),
          payload: channel_payload(round3),
          ttl: 1,
          fee: 1,
          nonce: 3
        })

      with_mocks [
        {Db, [:passthrough],
         [
           get_tx_data: fn tx_hash when tx_hash in [tx_hash1, tx_hash2, tx_hash3] ->
             case tx_hash do
               ^tx_hash1 ->
                 {_mod, tx_rec} = :aetx.specialize_type(tx1)
                 {mb_hash, :channel_close_solo_tx, :aetx_sign.new(tx1, []), tx_rec}

               ^tx_hash2 ->
                 {_mod, tx_rec} = :aetx.specialize_type(tx2)
                 {mb_hash, :channel_slash_tx, :aetx_sign.new(tx2, []), tx_rec}

               ^tx_hash3 ->
                 {_mod, tx_rec} = :aetx.specialize_type(tx3)
                 {mb_hash, :channel_snapshot_solo_tx, :aetx_sign.new(tx3, []), tx_rec}
             end
           end
         ]},
        {:aec_db, [:passthrough],
         find_tx_location: fn tx_hash when tx_hash in [tx_hash1, tx_hash2, tx_hash3] ->
           mb_hash
         end,
         get_header: fn ^mb_hash -> mb_header end},
        {:aec_chain, [:passthrough], [get_header: fn ^mb_hash -> {:ok, mb_header} end]},
        {:aec_headers, [:passthrough], [height: fn ^mb_header -> 0 end]}
      ] do
        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {0, 0}, id: tx_hash1))
          |> Store.put(Model.Tx, Model.tx(index: 2, block_index: {0, 0}, id: tx_hash2))
          |> Store.put(Model.Tx, Model.tx(index: 3, block_index: {0, 0}, id: tx_hash3))
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 3, hash: mb_hash))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 4))
          |> Store.put(
            Model.ActiveChannel,
            Model.channel(index: <<1::256>>, initiator: initiator_pk1, responder: responder_pk1)
          )
          |> Store.put(
            Model.ActiveChannel,
            Model.channel(index: <<2::256>>, initiator: initiator_pk2, responder: responder_pk2)
          )
          |> Store.put(
            Model.ActiveChannel,
            Model.channel(index: <<3::256>>, initiator: initiator_pk3, responder: responder_pk3)
          )

        initiator_id1 = encode_account(initiator_pk1)
        initiator_id2 = encode_account(initiator_pk2)
        initiator_id3 = encode_account(initiator_pk3)

        responder_id1 = encode_account(responder_pk1)
        responder_id2 = encode_account(responder_pk2)
        responder_id3 = encode_account(responder_pk3)

        from_id1 = encode_account(from_pk1)
        from_id2 = encode_account(from_pk2)
        from_id3 = encode_account(from_pk3)

        assert %{
                 "tx" => %{
                   "from_id" => ^from_id1,
                   "initiator_id" => ^initiator_id1,
                   "responder_id" => ^responder_id1,
                   "round" => ^round1,
                   "type" => "ChannelCloseSoloTx"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{encode(:tx_hash, tx_hash1)}")
                 |> json_response(200)

        assert %{
                 "tx" => %{
                   "from_id" => ^from_id2,
                   "initiator_id" => ^initiator_id2,
                   "responder_id" => ^responder_id2,
                   "round" => ^round2,
                   "type" => "ChannelSlashTx"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{encode(:tx_hash, tx_hash2)}")
                 |> json_response(200)

        assert %{
                 "tx" => %{
                   "from_id" => ^from_id3,
                   "initiator_id" => ^initiator_id3,
                   "responder_id" => ^responder_id3,
                   "round" => ^round3,
                   "type" => "ChannelSnapshotSoloTx"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{encode(:tx_hash, tx_hash3)}")
                 |> json_response(200)
      end
    end

    test "returns channel participants", %{conn: conn, store: store} do
      {initiator_pk1, responder_pk1} =
        {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32)}

      {initiator_pk2, responder_pk2} =
        {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32)}

      {initiator_pk3, responder_pk3} =
        {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32)}

      from_pk1 = :crypto.strong_rand_bytes(32)
      from_pk2 = :crypto.strong_rand_bytes(32)
      from_pk3 = :crypto.strong_rand_bytes(32)

      tx_hash1 = :crypto.strong_rand_bytes(32)
      tx_hash2 = :crypto.strong_rand_bytes(32)
      tx_hash3 = :crypto.strong_rand_bytes(32)

      mb_hash = :crypto.strong_rand_bytes(32)
      mb_header = some_mb_header()

      {:ok, tx1} =
        :aesc_force_progress_tx.new(%{
          channel_id: :aeser_id.create(:channel, <<1::256>>),
          from_id: :aeser_id.create(:account, from_pk1),
          payload: channel_payload(11),
          update: :aesc_offchain_update.op_meta(<<123>>),
          state_hash: <<1::256>>,
          round: 11,
          offchain_trees: :aec_trees.new(),
          fee: 1,
          nonce: 1
        })

      {:ok, tx2} =
        :aesc_settle_tx.new(%{
          channel_id: :aeser_id.create(:channel, <<2::256>>),
          from_id: :aeser_id.create(:account, from_pk2),
          initiator_amount_final: 100,
          responder_amount_final: 200,
          ttl: 1,
          fee: 1,
          nonce: 2
        })

      {:ok, tx3} =
        :aesc_close_mutual_tx.new(%{
          channel_id: :aeser_id.create(:channel, <<3::256>>),
          from_id: :aeser_id.create(:account, from_pk3),
          initiator_amount_final: 100,
          responder_amount_final: 200,
          ttl: 1,
          fee: 1,
          nonce: 3
        })

      with_mocks [
        {Db, [:passthrough],
         [
           get_tx_data: fn tx_hash when tx_hash in [tx_hash1, tx_hash2, tx_hash3] ->
             case tx_hash do
               ^tx_hash1 ->
                 {_mod, tx_rec} = :aetx.specialize_type(tx1)
                 {mb_hash, :channel_force_progress_tx, :aetx_sign.new(tx1, []), tx_rec}

               ^tx_hash2 ->
                 {_mod, tx_rec} = :aetx.specialize_type(tx2)
                 {mb_hash, :channel_settle_tx, :aetx_sign.new(tx2, []), tx_rec}

               ^tx_hash3 ->
                 {_mod, tx_rec} = :aetx.specialize_type(tx3)
                 {mb_hash, :channel_close_mutual_tx, :aetx_sign.new(tx3, []), tx_rec}
             end
           end
         ]},
        {:aec_db, [:passthrough],
         find_tx_location: fn tx_hash when tx_hash in [tx_hash1, tx_hash2, tx_hash3] ->
           mb_hash
         end,
         get_header: fn ^mb_hash -> mb_header end},
        {:aec_chain, [:passthrough], [get_header: fn ^mb_hash -> {:ok, mb_header} end]},
        {:aec_headers, [:passthrough], [height: fn ^mb_header -> 0 end]}
      ] do
        store =
          store
          |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {0, 0}, id: tx_hash1))
          |> Store.put(Model.Tx, Model.tx(index: 2, block_index: {0, 0}, id: tx_hash2))
          |> Store.put(Model.Tx, Model.tx(index: 3, block_index: {0, 0}, id: tx_hash3))
          |> Store.put(Model.Block, Model.block(index: {0, -1}, tx_index: 1))
          |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 3, hash: mb_hash))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 4))
          |> Store.put(
            Model.ActiveChannel,
            Model.channel(index: <<1::256>>, initiator: initiator_pk1, responder: responder_pk1)
          )
          |> Store.put(
            Model.ActiveChannel,
            Model.channel(index: <<2::256>>, initiator: initiator_pk2, responder: responder_pk2)
          )
          |> Store.put(
            Model.ActiveChannel,
            Model.channel(index: <<3::256>>, initiator: initiator_pk3, responder: responder_pk3)
          )

        initiator_id1 = encode_account(initiator_pk1)
        initiator_id2 = encode_account(initiator_pk2)
        initiator_id3 = encode_account(initiator_pk3)

        responder_id1 = encode_account(responder_pk1)
        responder_id2 = encode_account(responder_pk2)
        responder_id3 = encode_account(responder_pk3)

        from_id1 = encode_account(from_pk1)
        from_id2 = encode_account(from_pk2)
        from_id3 = encode_account(from_pk3)

        assert %{
                 "tx" => %{
                   "from_id" => ^from_id1,
                   "initiator_id" => ^initiator_id1,
                   "responder_id" => ^responder_id1,
                   "type" => "ChannelForceProgressTx"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{encode(:tx_hash, tx_hash1)}")
                 |> json_response(200)

        assert %{
                 "tx" => %{
                   "from_id" => ^from_id2,
                   "initiator_id" => ^initiator_id2,
                   "responder_id" => ^responder_id2,
                   "type" => "ChannelSettleTx"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{encode(:tx_hash, tx_hash2)}")
                 |> json_response(200)

        assert %{
                 "tx" => %{
                   "from_id" => ^from_id3,
                   "initiator_id" => ^initiator_id3,
                   "responder_id" => ^responder_id3,
                   "type" => "ChannelCloseMutualTx"
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/txs/#{encode(:tx_hash, tx_hash3)}")
                 |> json_response(200)
      end
    end

    test "when non-existent txi, it returns an error", %{conn: conn, store: store} do
      error_msg = "not found: 123"

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v2/txs/123")
               |> json_response(404)
    end
  end

  describe "count" do
    test "it returns all tx count by default", %{conn: conn, store: store} do
      tx = Model.tx(index: tx_index) = TS.tx(0)
      store = Store.put(store, Model.Tx, tx)

      assert ^tx_index =
               conn
               |> with_store(store)
               |> get("/v2/txs/count")
               |> json_response(200)
    end

    test "it returns the difference between first and last txi", %{conn: conn} do
      first_txi = 600
      last_txi = 500

      assert 101 =
               conn
               |> get("/v2/txs/count", scope: "txi:#{first_txi}-#{last_txi}")
               |> json_response(200)
    end

    test "it returns the difference between first and last gen", %{conn: conn, store: store} do
      first_gen = 600
      last_gen = 500

      store =
        store
        |> Store.put(Model.Block, Model.block(index: {last_gen, -1}, tx_index: 700))
        |> Store.put(Model.Block, Model.block(index: {first_gen + 1, -1}, tx_index: 800))

      assert 100 =
               conn
               |> with_store(store)
               |> get("/v2/txs/count", scope: "gen:#{first_gen}-#{last_gen}")
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
               |> get("/v2/txs/count", type: "oracle_register")
               |> json_response(200)

      assert ^count =
               conn
               |> with_store(store)
               |> get("/v2/txs/count", tx_type: "oracle_register")
               |> json_response(200)

      assert 0 =
               conn
               |> with_store(store)
               |> get("/v2/txs/count", tx_type: "oracle_response")
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
               |> get("/v2/txs/count", tx_type: "oracle_register")
               |> json_response(200)
    end

    test "returns the count of transactions of an account filtered by type", %{
      conn: conn,
      store: store
    } do
      address = TS.address(0)
      account_id = encode_account(address)

      store =
        store
        |> Store.put(
          Model.IdCount,
          Model.id_count(index: {:oracle_extend_tx, 1, address}, count: 10)
        )
        |> Store.put(Model.IdCount, Model.id_count(index: {:spend_tx, 1, address}, count: 3))
        |> Store.put(Model.IdCount, Model.id_count(index: {:spend_tx, 2, address}, count: 2))

      assert 5 =
               conn
               |> with_store(store)
               |> get("/v2/txs/count", id: account_id, type: "spend")
               |> json_response(200)
    end
  end

  describe "count_id" do
    test "returns the count of transactions involving the id", %{
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
               |> get("/v2/txs/count", id: enc_address)
               |> json_response(200)
    end

    test "returns the count of transactions of a type involving the id", %{
      conn: conn,
      store: store
    } do
      address = TS.address(0)
      enc_address = :aeser_api_encoder.encode(:account_pubkey, address)

      store =
        store
        |> Store.put(
          Model.IdCount,
          Model.id_count(index: {:oracle_extend_tx, 1, address}, count: 10)
        )
        |> Store.put(Model.IdCount, Model.id_count(index: {:spend_tx, 1, address}, count: 3))
        |> Store.put(Model.IdCount, Model.id_count(index: {:spend_tx, 2, address}, count: 2))

      assert 5 =
               conn
               |> with_store(store)
               |> get("/v2/txs/count/#{enc_address}", type: "spend")
               |> json_response(200)
    end

    test "returns the count of transactions of a type group involving the id", %{
      conn: conn,
      store: store
    } do
      address = TS.address(0)
      enc_address = :aeser_api_encoder.encode(:contract_pubkey, address)

      store =
        store
        |> Store.put(
          Model.IdCount,
          Model.id_count(index: {:oracle_extend_tx, 1, address}, count: 10)
        )
        |> Store.put(
          Model.IdCount,
          Model.id_count(index: {:contract_create_tx, 1, address}, count: 3)
        )
        |> Store.put(
          Model.IdCount,
          Model.id_count(index: {:contract_call_tx, 1, address}, count: 4)
        )
        |> Store.put(
          Model.IdCount,
          Model.id_count(index: {:contract_call_tx, 3, address}, count: 5)
        )

      assert 12 =
               conn
               |> with_store(store)
               |> get("/v2/txs/count/#{enc_address}", type_group: "contract")
               |> json_response(200)
    end

    test "when filtering by invalid type, it displays an error", %{conn: conn} do
      error_msg = "invalid transaction type: oracle_foo"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/txs/count", type: "oracle_foo")
               |> json_response(400)
    end

    test "when filtering by invalid id, it displays an error", %{conn: conn} do
      error_msg = "invalid id: foo"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/txs/count", id: "foo")
               |> json_response(400)
    end

    test "when filtering by type and invalid id, it displays an error", %{conn: conn} do
      error_msg = "invalid id: foo"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/txs/count/foo", type: "oracle_query")
               |> json_response(400)
    end

    test "when filtering by group and invalid id, it displays an error", %{conn: conn} do
      error_msg = "invalid id: foo"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/txs/count/foo", type_group: "oracle")
               |> json_response(400)
    end

    test "when filtering by id and scoping, it displays an error", %{conn: conn} do
      id = Enc.encode(:account_pubkey, TS.address(0))
      error_msg = "invalid query: can't query by multiple filters and/or invalid filters"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/txs/count", id: id, scope: "gen:1-2")
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

  defp channel_payload(round) do
    channel_id = :aeser_id.create(:channel, <<1::256>>)

    {:ok, offchain_tx} =
      :aesc_offchain_tx.new(%{
        channel_id: channel_id,
        state_hash: <<1::256>>,
        round: round,
        updates: []
      })

    :aetx_sign.serialize_to_binary(:aetx_sign.new(offchain_tx, []))
  end

  defp some_mb_header do
    :aec_headers.new_micro_header(
      0,
      <<0::256>>,
      <<0::256>>,
      <<0::256>>,
      1,
      <<0::256>>,
      <<0::256>>,
      1
    )
  end

  defp proof_of_inclusion(participants) do
    accounts = for {pubkey, balance} <- participants, do: :aec_accounts.new(pubkey, balance)

    trees = create_state_tree_with_accounts(accounts)

    Enum.reduce(participants, :aec_trees.new_poi(trees), fn {pubkey, _balance}, acc ->
      {:ok, acc1} = :aec_trees.add_poi(:accounts, pubkey, trees, acc)
      acc1
    end)
  end

  defp create_state_tree_with_accounts(accounts) do
    state_trees = :aec_trees.new_without_backend()
    accounts_trees = :aec_trees.accounts(state_trees)
    accounts_trees = Enum.reduce(accounts, accounts_trees, &:aec_accounts_trees.enter/2)

    :aec_trees.set_accounts(state_trees, accounts_trees)
  end
end
