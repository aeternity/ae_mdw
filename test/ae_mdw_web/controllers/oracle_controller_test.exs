defmodule AeMdwWeb.OracleControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Model.ActiveOracleExpiration
  alias AeMdw.Db.Model.Block
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Store
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Database
  alias AeMdw.TestSamples, as: TS

  import Mock

  require Model

  describe "oracles" do
    test "it retrieves active oracles first", %{conn: conn, store: store} do
      Model.oracle(index: oracle_pk1) =
        oracle =
        Model.oracle(
          TS.oracle(),
          register: {{999, 0}, {2000, -1}}
        )

      oracle_pk2 = <<0::256>>
      block_hash1 = <<1::256>>
      tx_hash1 = <<2::256>>
      tx_hash2 = <<3::256>>
      last_gen = 1000
      last_time = 123
      expiration1 = 1002
      expiration2 = 1004
      encoded_pk1 = :aeser_api_encoder.encode(:oracle_pubkey, oracle_pk1)
      encoded_pk2 = :aeser_api_encoder.encode(:oracle_pubkey, oracle_pk2)
      expiration_time1 = last_time + (expiration1 - last_gen) * 180_000
      expiration_time2 = last_time + (expiration2 - last_gen) * 180_000

      store =
        store
        |> Store.put(
          Model.ActiveOracleExpiration,
          Model.expiration(index: {expiration1, oracle_pk1})
        )
        |> Store.put(
          Model.ActiveOracleExpiration,
          Model.expiration(index: {expiration2, oracle_pk2})
        )
        |> Store.put(Model.Block, Model.block(index: {last_gen, -1}, hash: block_hash1))
        |> Store.put(Model.ActiveOracle, Model.oracle(oracle, expire: expiration1))
        |> Store.put(
          Model.ActiveOracle,
          Model.oracle(oracle, index: oracle_pk2, expire: expiration2)
        )
        |> Store.put(Model.Tx, Model.tx(index: 8916, id: tx_hash1))
        |> Store.put(Model.Block, Model.block(index: {999, 0}, hash: block_hash1))
        |> Store.put(Model.Tx, Model.tx(index: 2000, id: tx_hash2))

      with_mocks [
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {:aec_db, [], [get_block: fn ^block_hash1 -> :block end]},
        {:aec_blocks, [], [time_in_msecs: fn :block -> last_time end]}
      ] do
        assert %{"data" => [oracle2, oracle1], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get("/oracles")
                 |> json_response(200)

        assert %{
                 "oracle" => ^encoded_pk2,
                 "approximate_expire_time" => ^expiration_time2,
                 "register_time" => 123
               } = oracle2

        assert %{"oracle" => ^encoded_pk1, "approximate_expire_time" => ^expiration_time1} =
                 oracle1
      end
    end

    test "it retrieves both active and inactive when length(active) < limit", %{
      conn: conn,
      store: store
    } do
      Model.oracle(index: oracle_pk1) =
        oracle =
        Model.oracle(
          TS.oracle(),
          register: {{0, -1}, {8916, -1}}
        )

      [oracle_pk2, oracle_pk3, oracle_pk4] = [<<1::256>>, <<2::256>>, <<3::256>>]
      [expiration1, expiration2, expiration3, expiration4] = [50, 51, 2000, 3000]
      block_hash1 = <<4::256>>
      block_hash2 = <<5::256>>
      block_hash3 = <<6::256>>
      tx_hash1 = <<7::256>>
      last_gen = 1000
      last_time = 123
      [block_time1, block_time2] = [111, 222]
      expiration_time1 = block_time1
      expiration_time2 = block_time2
      expiration_time3 = last_time + (expiration3 - last_gen) * 180_000
      expiration_time4 = last_time + (expiration4 - last_gen) * 180_000
      encoded_pk1 = :aeser_api_encoder.encode(:oracle_pubkey, oracle_pk1)
      encoded_pk2 = :aeser_api_encoder.encode(:oracle_pubkey, oracle_pk2)
      encoded_pk3 = :aeser_api_encoder.encode(:oracle_pubkey, oracle_pk3)
      encoded_pk4 = :aeser_api_encoder.encode(:oracle_pubkey, oracle_pk4)

      store =
        store
        |> Store.put(
          Model.InactiveOracleExpiration,
          Model.expiration(index: {expiration1, oracle_pk1})
        )
        |> Store.put(
          Model.InactiveOracleExpiration,
          Model.expiration(index: {expiration2, oracle_pk2})
        )
        |> Store.put(
          Model.ActiveOracleExpiration,
          Model.expiration(index: {expiration3, oracle_pk3})
        )
        |> Store.put(
          Model.ActiveOracleExpiration,
          Model.expiration(index: {expiration4, oracle_pk4})
        )
        |> Store.put(Model.Block, Model.block(index: {0, -1}, hash: block_hash1))
        |> Store.put(Model.Block, Model.block(index: {last_gen, -1}, hash: block_hash3))
        |> Store.put(Model.Block, Model.block(index: {expiration1 - 1, -1}, hash: block_hash1))
        |> Store.put(Model.Block, Model.block(index: {expiration2 - 1, -1}, hash: block_hash2))
        |> Store.put(Model.Block, Model.block(index: {expiration1, -1}, hash: block_hash1))
        |> Store.put(Model.Block, Model.block(index: {expiration2, -1}, hash: block_hash2))
        |> Store.put(Model.InactiveOracle, Model.oracle(oracle, expire: expiration1))
        |> Store.put(
          Model.InactiveOracle,
          Model.oracle(oracle, index: oracle_pk2, expire: expiration2)
        )
        |> Store.put(
          Model.ActiveOracle,
          Model.oracle(oracle, index: oracle_pk3, expire: expiration3)
        )
        |> Store.put(
          Model.ActiveOracle,
          Model.oracle(oracle, index: oracle_pk4, expire: expiration4)
        )
        |> Store.put(Model.Tx, Model.tx(index: 8916, id: tx_hash1))

      with_mocks [
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {:aec_db, [],
         [
           get_block: fn
             ^block_hash1 -> :block1
             ^block_hash2 -> :block2
             ^block_hash3 -> :block3
           end
         ]},
        {:aec_blocks, [],
         [
           time_in_msecs: fn
             :block1 -> block_time1
             :block2 -> block_time2
             :block3 -> last_time
           end
         ]}
      ] do
        assert %{"data" => [oracle1, oracle2, oracle3, oracle4], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get("/oracles", direction: "forward")
                 |> json_response(200)

        assert %{
                 "active" => false,
                 "oracle" => ^encoded_pk1,
                 "approximate_expire_time" => ^expiration_time1,
                 "register_time" => 111
               } = oracle1

        assert %{
                 "active" => false,
                 "oracle" => ^encoded_pk2,
                 "approximate_expire_time" => ^expiration_time2,
                 "register_time" => 111
               } = oracle2

        assert %{
                 "active" => true,
                 "oracle" => ^encoded_pk3,
                 "approximate_expire_time" => ^expiration_time3,
                 "register_time" => 111
               } = oracle3

        assert %{
                 "active" => true,
                 "oracle" => ^encoded_pk4,
                 "approximate_expire_time" => ^expiration_time4,
                 "register_time" => 111
               } = oracle4
      end
    end

    test "it displays tx hashes when tx_hash=true", %{conn: conn, store: store} do
      register_tx1 = Model.tx(index: register_txi1, id: register_tx_hash1) = TS.tx(0)
      register_tx2 = Model.tx(index: register_txi2, id: register_tx_hash2) = TS.tx(1)
      extends_tx = Model.tx(index: extends_txi, id: extends_tx_hash) = TS.tx(2)
      oracle_exp1 = {exp_height1, oracle_pk1} = TS.oracle_expiration_key(0)
      oracle_exp2 = {exp_height2, oracle_pk2} = TS.oracle_expiration_key(1)

      oracle1 =
        Model.oracle(TS.oracle(),
          index: oracle_pk1,
          register: {{0, -1}, {register_txi1, -1}},
          expire: exp_height1,
          extends: [{{0, -1}, {extends_txi, -1}}]
        )

      oracle2 =
        Model.oracle(TS.oracle(),
          index: oracle_pk2,
          register: {{0, -1}, {register_txi2, -1}},
          expire: exp_height2,
          extends: []
        )

      block_hash = TS.key_block_hash(0)

      store =
        store
        |> Store.put(Model.Tx, register_tx1)
        |> Store.put(Model.Tx, register_tx2)
        |> Store.put(Model.Tx, extends_tx)
        |> Store.put(Model.ActiveOracleExpiration, Model.expiration(index: oracle_exp1))
        |> Store.put(Model.ActiveOracleExpiration, Model.expiration(index: oracle_exp2))
        |> Store.put(Model.ActiveOracle, oracle1)
        |> Store.put(Model.ActiveOracle, oracle2)
        |> Store.put(Model.Block, Model.block(index: {0, -1}, hash: block_hash))
        |> Store.put(Model.Block, Model.block(index: {exp_height1, -1}, hash: block_hash))
        |> Store.put(Model.Block, Model.block(index: {exp_height2, -1}, hash: block_hash))
        |> Store.put(Model.Block, Model.block(index: {exp_height1 - 1, -1}, hash: block_hash))
        |> Store.put(Model.Block, Model.block(index: {exp_height2 - 1, -1}, hash: block_hash))

      with_mocks [
        {Oracle, [], [oracle_tree!: fn ^block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {:aec_db, [], [get_block: fn ^block_hash -> :block end]},
        {:aec_blocks, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => [oracle2, oracle1], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get("/oracles", tx_hash: "true", limit: 2)
                 |> json_response(200)

        assert %{
                 "register_tx_hash" => register_hash,
                 "extends" => [extends_hash],
                 "register_time" => 123
               } = oracle1

        assert {:ok, ^register_tx_hash1} = Enc.safe_decode(:tx_hash, register_hash)
        assert {:ok, ^extends_tx_hash} = Enc.safe_decode(:tx_hash, extends_hash)

        assert %{"register_tx_hash" => register_hash, "extends" => [], "register_time" => 123} =
                 oracle2

        assert {:ok, ^register_tx_hash2} = Enc.safe_decode(:tx_hash, register_hash)
      end
    end

    test "when both tx_hash and expand is sent, it displays error", %{conn: conn} do
      assert %{"error" => "either `tx_hash` or `expand` parameters should be used, but not both."} =
               conn
               |> get("/oracles", tx_hash: "true", expand: "true")
               |> json_response(400)
    end
  end

  describe "active_oracles" do
    test "it retrieves all active oracles backwards by default", %{conn: conn} do
      key1 = TS.oracle_expiration_key(1)
      key2 = TS.oracle_expiration_key(2)
      Model.oracle(index: pk) = oracle = TS.oracle()
      encoded_pk = :aeser_api_encoder.encode(:oracle_pubkey, pk)
      block_hash = <<0::256>>

      with_mocks [
        {Database, [],
         [
           last_key: fn
             Block -> {:ok, TS.last_gen()}
             ActiveOracleExpiration -> {:ok, key1}
           end,
           get: fn
             Model.ActiveOracle, _oracle_pk -> {:ok, oracle}
             Model.Tx, _txi -> {:ok, Model.tx(id: TS.tx_hash(0))}
             Model.Block, _block_index -> {:ok, Model.block(hash: block_hash)}
           end,
           next_key: fn _tab, _key -> :none end,
           prev_key: fn
             _tab, ^key1 -> {:ok, key2}
             _tab, ^key2 -> :none
           end
         ]},
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {Blocks, [], [block_hash: fn _state, _height -> "asd" end]},
        {:aec_db, [], [get_block: fn ^block_hash -> :block1 end]},
        {:aec_blocks, [], [time_in_msecs: fn :block1 -> 123 end]}
      ] do
        assert %{"data" => [oracle1, _oracle2], "next" => nil} =
                 conn
                 |> get("/oracles/active")
                 |> json_response(200)

        assert %{"oracle" => ^encoded_pk} = oracle1

        assert_called(Database.last_key(Block))
      end
    end

    test "it provides a 'next' cursor when more than limit of 10", %{conn: conn} do
      expiration_key = {next_cursor_exp, next_cursor_pk} = TS.oracle_expiration_key(0)
      next_cursor_pk_encoded = :aeser_api_encoder.encode(:oracle_pubkey, next_cursor_pk)
      next_cursor_query_value = "#{next_cursor_exp}-#{next_cursor_pk_encoded}"
      block_hash = <<0::256>>

      with_mocks [
        {Database, [],
         [
           last_key: fn
             Model.Block -> {:ok, TS.last_gen()}
             Model.ActiveOracleExpiration -> {:ok, expiration_key}
           end,
           next_key: fn Model.ActiveOracleExpiration, _key -> {:ok, expiration_key} end,
           prev_key: fn Model.ActiveOracleExpiration, _key -> {:ok, expiration_key} end,
           get: fn
             Model.ActiveOracle, _oracle_pk -> {:ok, TS.oracle()}
             Model.Tx, _txi -> {:ok, Model.tx(id: TS.tx_hash(0))}
             Model.Block, _block_index -> {:ok, Model.block(hash: block_hash)}
           end
         ]},
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {Blocks, [], [block_hash: fn _state, _height -> "asd" end]},
        {:aec_db, [], [get_block: fn ^block_hash -> :block1 end]},
        {:aec_blocks, [], [time_in_msecs: fn :block1 -> 123 end]}
      ] do
        assert %{"next" => next_uri} = conn |> get("/oracles/active") |> json_response(200)

        assert %URI{
                 path: "/oracles/active",
                 query: query
               } = URI.parse(next_uri)

        assert %{"cursor" => ^next_cursor_query_value} = URI.decode_query(query)
      end
    end
  end

  describe "oracle_queries" do
    test "it retrieves all oracle queries", %{conn: conn, store: store} do
      oracle_pk = <<1::256>>
      oracle_pk2 = <<2::256>>
      query_id1 = <<3::256>>
      query_id2 = <<4::256>>
      query_id3 = <<5::256>>
      query_id4 = <<6::256>>
      account_pk1 = <<7::256>>
      account_pk2 = <<8::256>>
      oracle_id = :aeser_id.create(:oracle, oracle_pk)
      account_id1 = :aeser_id.create(:account, account_pk1)
      account_id2 = :aeser_id.create(:account, account_pk2)
      encoded_account_id1 = Enc.encode(:account_pubkey, account_pk1)
      encoded_account_id2 = Enc.encode(:account_pubkey, account_pk2)
      encoded_oracle_pk = Enc.encode(:oracle_pubkey, oracle_pk)
      encoded_query_id1 = Enc.encode(:oracle_query_id, query_id1)
      encoded_query_id2 = Enc.encode(:oracle_query_id, query_id2)
      encoded_query_id3 = Enc.encode(:oracle_query_id, query_id3)
      txi_idx1 = {789, -1}
      tx_hash1 = <<10::256>>
      txi_idx2 = {791, 3}
      tx_hash2 = <<11::256>>
      txi_idx3 = {799, -1}
      tx_hash3 = <<12::256>>
      block_hash = <<13::256>>

      {:ok, oracle_query_aetx1} =
        :aeo_query_tx.new(%{
          sender_id: account_id1,
          nonce: 1,
          oracle_id: oracle_id,
          query: "query-1",
          query_fee: 11,
          query_ttl: {:delta, 111},
          response_ttl: {:delta, 1_111},
          fee: 11_111
        })

      {:ok, oracle_query_aetx2} =
        :aeo_query_tx.new(%{
          sender_id: account_id2,
          nonce: 2,
          oracle_id: oracle_id,
          query: "query-2",
          query_fee: 22,
          query_ttl: {:delta, 222},
          response_ttl: {:delta, 2_222},
          fee: 22_222
        })

      {:ok, oracle_query_aetx3} =
        :aeo_query_tx.new(%{
          sender_id: account_id1,
          nonce: 3,
          oracle_id: oracle_id,
          query: <<0, 2, 2>>,
          query_fee: 33,
          query_ttl: {:delta, 333},
          response_ttl: {:delta, 3_333},
          fee: 33_333
        })

      {:oracle_query_tx, oracle_query_tx1} = :aetx.specialize_type(oracle_query_aetx1)
      {:oracle_query_tx, oracle_query_tx2} = :aetx.specialize_type(oracle_query_aetx2)
      {:oracle_query_tx, oracle_query_tx3} = :aetx.specialize_type(oracle_query_aetx3)

      store =
        store
        |> Store.put(
          Model.OracleQuery,
          Model.oracle_query(index: {oracle_pk, query_id1}, txi_idx: txi_idx1)
        )
        |> Store.put(Model.Tx, Model.tx(index: 789, id: tx_hash1))
        |> Store.put(
          Model.OracleQuery,
          Model.oracle_query(index: {oracle_pk, query_id2}, txi_idx: txi_idx2)
        )
        |> Store.put(Model.Tx, Model.tx(index: 791, id: tx_hash2))
        |> Store.put(
          Model.OracleQuery,
          Model.oracle_query(index: {oracle_pk, query_id3}, txi_idx: txi_idx3)
        )
        |> Store.put(Model.Tx, Model.tx(index: 799, id: tx_hash3))
        |> Store.put(Model.OracleQuery, Model.oracle_query(index: {oracle_pk2, query_id4}))

      with_mocks [
        {DbUtil, [:passthrough],
         [
           read_node_tx_details: fn
             _state, ^txi_idx1 ->
               {oracle_query_tx1, :oracle_query_tx, tx_hash1, :oracle_query_tx, block_hash}

             _state, ^txi_idx2 ->
               {oracle_query_tx2, :oracle_query_tx, tx_hash2, :contract_call_tx, block_hash}

             _state, ^txi_idx3 ->
               {oracle_query_tx3, :oracle_query_tx, tx_hash3, :oracle_query_tx, block_hash}
           end
         ]},
        {:aec_db, [], [get_block: fn _block_hash -> :block end]},
        {:aec_blocks, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => [oracle1, oracle2], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/oracles/#{encoded_oracle_pk}/queries", direction: "forward", limit: 2)
                 |> json_response(200)

        assert %{
                 "oracle_id" => ^encoded_oracle_pk,
                 "query_id" => ^encoded_query_id1,
                 "nonce" => 1,
                 "query_fee" => 11,
                 "sender_id" => ^encoded_account_id1,
                 "source_tx_type" => "OracleQueryTx",
                 "query" => "cXVlcnktMQ",
                 "fee" => 11_111,
                 "block_time" => 123
               } = oracle1

        assert %{
                 "oracle_id" => ^encoded_oracle_pk,
                 "query_id" => ^encoded_query_id2,
                 "nonce" => 2,
                 "query_fee" => 22,
                 "sender_id" => ^encoded_account_id2,
                 "source_tx_type" => "ContractCallTx",
                 "query" => "cXVlcnktMg",
                 "fee" => 22_222,
                 "block_time" => 123
               } = oracle2

        assert %{"data" => [oracle3], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        assert %{
                 "oracle_id" => ^encoded_oracle_pk,
                 "query_id" => ^encoded_query_id3,
                 "nonce" => 3,
                 "query_fee" => 33,
                 "sender_id" => ^encoded_account_id1,
                 "source_tx_type" => "OracleQueryTx",
                 "query" => "AAIC",
                 "fee" => 33_333
               } = oracle3
      end
    end

    test "cursor is invalid, it displays error", %{conn: conn} do
      oracle_pk = <<1::256>>
      encoded_oracle_pk = Enc.encode(:oracle_pubkey, oracle_pk)

      assert %{"error" => "invalid cursor: foo"} =
               conn
               |> get("/v2/oracles/#{encoded_oracle_pk}/queries", cursor: "foo")
               |> json_response(400)
    end
  end

  describe "oracle_responses" do
    test "it retrieves all oracle responses", %{conn: conn, store: store} do
      height = 707
      oracle_pk = <<1::256>>
      oracle_pk2 = <<2::256>>
      query_id1 = <<3::256>>
      query_id2 = <<4::256>>
      query_id3 = <<5::256>>
      query_id4 = <<6::256>>
      account_pk1 = <<7::256>>
      account_pk2 = <<8::256>>
      oracle_id = :aeser_id.create(:oracle, oracle_pk)
      account_id1 = :aeser_id.create(:account, account_pk1)
      account_id2 = :aeser_id.create(:account, account_pk2)
      encoded_account_id1 = Enc.encode(:account_pubkey, account_pk1)
      encoded_account_id2 = Enc.encode(:account_pubkey, account_pk2)
      encoded_oracle_pk = Enc.encode(:oracle_pubkey, oracle_pk)
      encoded_query_id1 = Enc.encode(:oracle_query_id, query_id1)
      encoded_query_id2 = Enc.encode(:oracle_query_id, query_id2)
      encoded_query_id3 = Enc.encode(:oracle_query_id, query_id3)
      txi_idx1 = {789, -1}
      tx_hash1 = <<10::256>>
      txi_idx2 = {791, 3}
      tx_hash2 = <<11::256>>
      txi_idx3 = {799, -1}
      tx_hash3 = <<12::256>>
      block_hash1 = <<13::256>>
      txi_idx4 = {989, -1}
      tx_hash4 = <<14::256>>
      txi_idx5 = {991, 3}
      tx_hash5 = <<15::256>>
      txi_idx6 = {999, -1}
      tx_hash6 = <<16::256>>
      block_hash2 = <<17::256>>

      {:ok, oracle_query_aetx1} =
        :aeo_query_tx.new(%{
          sender_id: account_id1,
          nonce: 1,
          oracle_id: oracle_id,
          query: "query-1",
          query_fee: 11,
          query_ttl: {:delta, 111},
          response_ttl: {:delta, 1_111},
          fee: 11_111
        })

      {:ok, oracle_query_aetx2} =
        :aeo_query_tx.new(%{
          sender_id: account_id2,
          nonce: 2,
          oracle_id: oracle_id,
          query: "query-2",
          query_fee: 22,
          query_ttl: {:delta, 222},
          response_ttl: {:delta, 2_222},
          fee: 22_222
        })

      {:ok, oracle_query_aetx3} =
        :aeo_query_tx.new(%{
          sender_id: account_id1,
          nonce: 3,
          oracle_id: oracle_id,
          query: <<0, 2, 2>>,
          query_fee: 33,
          query_ttl: {:delta, 333},
          response_ttl: {:delta, 3_333},
          fee: 33_333
        })

      {:oracle_query_tx, oracle_query_tx1} = :aetx.specialize_type(oracle_query_aetx1)
      {:oracle_query_tx, oracle_query_tx2} = :aetx.specialize_type(oracle_query_aetx2)
      {:oracle_query_tx, oracle_query_tx3} = :aetx.specialize_type(oracle_query_aetx3)

      {:ok, oracle_response_aetx1} =
        :aeo_response_tx.new(%{
          oracle_id: oracle_id,
          nonce: 4,
          query_id: query_id1,
          response: "response-1",
          response_ttl: {:delta, 111},
          fee: 11_111
        })

      {:ok, oracle_response_aetx2} =
        :aeo_response_tx.new(%{
          oracle_id: oracle_id,
          nonce: 5,
          query_id: query_id2,
          response: "response-2",
          response_ttl: {:delta, 222},
          fee: 22_222
        })

      {:ok, oracle_response_aetx3} =
        :aeo_response_tx.new(%{
          oracle_id: oracle_id,
          nonce: 6,
          query_id: query_id3,
          response: <<0, 2, 2>>,
          response_ttl: {:delta, 333},
          fee: 33_333
        })

      {:oracle_response_tx, oracle_response_tx1} = :aetx.specialize_type(oracle_response_aetx1)
      {:oracle_response_tx, oracle_response_tx2} = :aetx.specialize_type(oracle_response_aetx2)
      {:oracle_response_tx, oracle_response_tx3} = :aetx.specialize_type(oracle_response_aetx3)

      store =
        store
        |> Store.put(
          Model.OracleQuery,
          Model.oracle_query(
            index: {oracle_pk, query_id1},
            txi_idx: txi_idx1,
            response_txi_idx: txi_idx4
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: 789, id: tx_hash1))
        |> Store.put(
          Model.OracleQuery,
          Model.oracle_query(
            index: {oracle_pk, query_id2},
            txi_idx: txi_idx2,
            response_txi_idx: txi_idx5
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: 791, id: tx_hash2))
        |> Store.put(
          Model.OracleQuery,
          Model.oracle_query(
            index: {oracle_pk, query_id3},
            txi_idx: txi_idx3,
            response_txi_idx: txi_idx6
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: 799, id: tx_hash3))
        |> Store.put(Model.OracleQuery, Model.oracle_query(index: {oracle_pk2, query_id4}))
        |> Store.put(
          Model.TargetKindIntTransferTx,
          Model.target_kind_int_transfer_tx(
            index: {oracle_pk, "reward_oracle", {height, txi_idx4}, txi_idx1}
          )
        )
        |> Store.put(
          Model.TargetKindIntTransferTx,
          Model.target_kind_int_transfer_tx(
            index: {oracle_pk, "reward_oracle", {height, txi_idx5}, txi_idx2}
          )
        )
        |> Store.put(
          Model.TargetKindIntTransferTx,
          Model.target_kind_int_transfer_tx(
            index: {oracle_pk, "reward_oracle", {height, txi_idx6}, txi_idx3}
          )
        )

      with_mocks [
        {DbUtil, [:passthrough],
         [
           read_node_tx_details: fn
             _state, ^txi_idx1 ->
               {oracle_query_tx1, :oracle_query_tx, tx_hash1, :oracle_query_tx, block_hash1}

             _state, ^txi_idx2 ->
               {oracle_query_tx2, :oracle_query_tx, tx_hash2, :contract_call_tx, block_hash1}

             _state, ^txi_idx3 ->
               {oracle_query_tx3, :oracle_query_tx, tx_hash3, :oracle_query_tx, block_hash1}

             _state, ^txi_idx4 ->
               {oracle_response_tx1, :oracle_response_tx, tx_hash4, :oracle_response_tx,
                block_hash2}

             _state, ^txi_idx5 ->
               {oracle_response_tx2, :oracle_response_tx, tx_hash5, :contract_call_tx,
                block_hash2}

             _state, ^txi_idx6 ->
               {oracle_response_tx3, :oracle_response_tx, tx_hash6, :oracle_response_tx,
                block_hash2}
           end
         ]},
        {:aec_db, [], [get_block: fn _key_hash -> :block end]},
        {:aec_blocks, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => [response1, response2], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/oracles/#{encoded_oracle_pk}/responses",
                   direction: "forward",
                   limit: 2
                 )
                 |> json_response(200)

        assert %{
                 "oracle_id" => ^encoded_oracle_pk,
                 "response" => "cmVzcG9uc2UtMQ",
                 "block_time" => 123,
                 "query" => %{
                   "oracle_id" => ^encoded_oracle_pk,
                   "query_id" => ^encoded_query_id1,
                   "nonce" => 1,
                   "query_fee" => 11,
                   "sender_id" => ^encoded_account_id1,
                   "source_tx_type" => "OracleQueryTx",
                   "query" => "cXVlcnktMQ",
                   "fee" => 11_111
                 }
               } = response1

        assert %{
                 "oracle_id" => ^encoded_oracle_pk,
                 "response" => "cmVzcG9uc2UtMg",
                 "block_time" => 123,
                 "query" => %{
                   "oracle_id" => ^encoded_oracle_pk,
                   "query_id" => ^encoded_query_id2,
                   "nonce" => 2,
                   "query_fee" => 22,
                   "sender_id" => ^encoded_account_id2,
                   "source_tx_type" => "ContractCallTx",
                   "query" => "cXVlcnktMg",
                   "fee" => 22_222
                 }
               } = response2

        assert %{"data" => [response3], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        assert %{
                 "oracle_id" => ^encoded_oracle_pk,
                 "response" => "AAIC",
                 "query" => %{
                   "oracle_id" => ^encoded_oracle_pk,
                   "query_id" => ^encoded_query_id3,
                   "nonce" => 3,
                   "query_fee" => 33,
                   "sender_id" => ^encoded_account_id1,
                   "source_tx_type" => "OracleQueryTx",
                   "query" => "AAIC",
                   "fee" => 33_333
                 }
               } = response3
      end
    end

    test "cursor is invalid, it displays error", %{conn: conn} do
      oracle_pk = <<1::256>>
      encoded_oracle_pk = Enc.encode(:oracle_pubkey, oracle_pk)

      assert %{"error" => "invalid cursor: foo"} =
               conn
               |> get("/v2/oracles/#{encoded_oracle_pk}/queries", cursor: "foo")
               |> json_response(400)
    end
  end
end
