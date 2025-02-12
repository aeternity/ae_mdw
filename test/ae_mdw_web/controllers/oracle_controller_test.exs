defmodule AeMdwWeb.OracleControllerTest do
  alias AeMdw.Db.Format
  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Store
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Sync.MemStoreCreator
  alias AeMdw.TestSamples, as: TS

  import Mock

  require Model

  @last_gen 1000
  @exp0 950
  @exp1 951
  @exp2 952
  @exp3 1101
  @exp4 1102

  @last_time 1_690_001_000

  # height -> time
  @node_times %{
    900 => 1_690_000_900,
    950 => 1_690_000_950,
    951 => 1_690_000_951,
    952 => 1_690_000_952,
    953 => 1_690_000_953,
    999 => @last_time,
    1000 => @last_time,
    1101 => @last_time + (1101 - @last_gen) * 180_000,
    1102 => @last_time + (1102 - @last_gen) * 180_000
  }

  setup_all do
    store = MemStoreCreator.create(NullStore.new())
    oracle_pk1 = :crypto.strong_rand_bytes(32)
    oracle_pk2 = :crypto.strong_rand_bytes(32)
    oracle_pk3 = :crypto.strong_rand_bytes(32)
    oracle_pk4 = :crypto.strong_rand_bytes(32)

    register_h1 = 901
    register_h2 = 902
    register_h3 = 991
    register_h4 = 992

    inactive_oracles =
      for i <- 1..18,
          do:
            Model.oracle(
              index: :crypto.strong_rand_bytes(32),
              expire: @exp0,
              register: {{register_h1, 0}, {1000 + i, -1}}
            )

    oracle1 =
      Model.oracle(index: oracle_pk1, expire: @exp1, register: {{register_h1, 0}, {1019, -1}})

    oracle2 =
      Model.oracle(index: oracle_pk2, expire: @exp2, register: {{register_h2, 0}, {1020, -1}})

    oracle1 = Model.oracle(oracle1, extends: [{{register_h2, 0}, {1021, -1}}])

    oracle3 =
      Model.oracle(index: oracle_pk3, expire: @exp3, register: {{register_h3, 0}, {2001, -1}})

    oracle4 =
      Model.oracle(index: oracle_pk4, expire: @exp4, register: {{register_h4, 0}, {2002, -1}})

    store =
      inactive_oracles
      |> Enum.reduce(store, fn Model.oracle(index: pk, expire: exp), store ->
        Store.put(
          store,
          Model.InactiveOracleExpiration,
          Model.expiration(index: {exp, pk})
        )
      end)
      |> Store.put(
        Model.InactiveOracleExpiration,
        Model.expiration(index: {@exp1, oracle_pk1})
      )
      |> Store.put(
        Model.InactiveOracleExpiration,
        Model.expiration(index: {@exp2, oracle_pk2})
      )
      |> Store.put(
        Model.ActiveOracleExpiration,
        Model.expiration(index: {@exp3, oracle_pk3})
      )
      |> Store.put(
        Model.ActiveOracleExpiration,
        Model.expiration(index: {@exp4, oracle_pk4})
      )
      |> Store.put(Model.Block, Model.block(index: {900, 0}, hash: <<900::256>>))
      |> Store.put(Model.Block, Model.block(index: {901, 0}, hash: <<901::256>>))
      |> Store.put(Model.Block, Model.block(index: {902, 0}, hash: <<902::256>>))
      |> Store.put(Model.Block, Model.block(index: {949, -1}, hash: <<949::256>>))
      |> Store.put(Model.Block, Model.block(index: {950, -1}, hash: <<950::256>>))
      |> Store.put(Model.Block, Model.block(index: {951, -1}, hash: <<951::256>>))
      |> Store.put(Model.Block, Model.block(index: {952, -1}, hash: <<952::256>>))
      |> Store.put(Model.Block, Model.block(index: {991, 0}, hash: <<991::256>>))
      |> Store.put(Model.Block, Model.block(index: {992, 0}, hash: <<992::256>>))
      |> Store.put(Model.Block, Model.block(index: {1000, -1}, hash: <<1000::256>>))
      |> Store.put(Model.InactiveOracle, oracle1)
      |> Store.put(Model.InactiveOracle, oracle2)
      |> Store.put(Model.ActiveOracle, oracle3)
      |> Store.put(Model.ActiveOracle, oracle4)
      |> then(fn store ->
        Enum.reduce(
          inactive_oracles,
          store,
          &Store.put(&2, Model.InactiveOracle, &1)
        )
      end)
      |> then(fn store ->
        Enum.reduce(1..21, store, fn i, store ->
          txi = 1000 + i

          Store.put(
            store,
            Model.Tx,
            Model.tx(index: txi, id: <<txi::256>>, block_index: {900, 0})
          )
        end)
      end)
      |> Store.put(Model.Tx, Model.tx(index: 2001, id: <<2001::256>>, block_index: {990, 0}))
      |> Store.put(Model.Tx, Model.tx(index: 2002, id: <<2002::256>>, block_index: {990, 0}))

    encoded_pks =
      for pk <- [oracle_pk1, oracle_pk2, oracle_pk3, oracle_pk4],
          do: :aeser_api_encoder.encode(:oracle_pubkey, pk)

    {:ok,
     store: store,
     inactive_oracles: [oracle_pk1, oracle_pk2],
     active_oracles: [oracle_pk3, oracle_pk4],
     register_times: [
       @node_times[register_h1],
       @node_times[register_h2],
       @node_times[register_h3],
       @node_times[register_h4]
     ],
     expiration_times: [
       @node_times[@exp1],
       @node_times[@exp2],
       @node_times[@exp3],
       @node_times[@exp4]
     ],
     encoded_pks: encoded_pks}
  end

  describe "oracles" do
    test "it retrieves an oracle", %{
      conn: conn,
      store: store,
      inactive_oracles: [oracle_id1 | _],
      encoded_pks: [encoded_oracle_id | _]
    } do
      account_pk1 = <<7::256>>
      account_id1 = :aeser_id.create(:account, account_pk1)
      oracle_id = :aeser_id.create(:oracle, oracle_id1)

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

      signed_tx1 = :aetx_sign.new(oracle_query_aetx1, [])
      block_hash = <<950::256>>

      with_mocks [
        {Oracle, [:passthrough], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {Format, [:passthrough],
         [
           to_map: fn _state, Model.tx(id: hash) ->
             %{
               "hash" => Enc.encode(:tx_hash, hash),
               "tx" => %{
                 "abi_version" => 0,
                 "account_id" => Enc.encode(:account_pubkey, account_pk1),
                 "nonce" => 1,
                 "fee" => 11_111,
                 "oracle_ttl" => %{"type" => "delta", "value" => 111},
                 "query_fee" => 11,
                 "type" => "OracleRegisterTx",
                 "version" => 1,
                 "tx_hash" => Enc.encode(:tx_hash, hash)
               }
             }
           end
         ]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {:aec_db, [],
         [
           get_header: fn <<height::256>> -> <<height::256>> end,
           find_tx_with_location: fn _tx_hash -> {block_hash, signed_tx1} end
         ]},
        {:aec_headers, [:passthrough],
         [time_in_msecs: fn <<height::256>> -> @node_times[height] end]}
      ] do
        assert oracle =
                 conn
                 |> with_store(store)
                 |> get("/v3/oracles/#{encoded_oracle_id}")
                 |> json_response(200)

        exp1_time = @node_times[@exp1]
        reg_time1 = @node_times[901]

        assert %{
                 "oracle" => ^encoded_oracle_id,
                 "approximate_expire_time" => ^exp1_time,
                 "register_time" => ^reg_time1,
                 "register_tx_hash" => tx_hash,
                 "register" => %{
                   "hash" => tx_hash,
                   "tx" => %{"type" => "OracleRegisterTx", "tx_hash" => tx_hash}
                 }
               } = oracle
      end
    end

    test "it retrieves active oracles first", %{
      conn: conn,
      store: store,
      register_times: [reg_time1, reg_time2, reg_time3, reg_time4],
      expiration_times: [exp_time1, exp_time2, exp_time3, exp_time4],
      encoded_pks: [id1, id2, id3, id4]
    } do
      with_mocks [
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {:aec_db, [],
         [get_header: fn <<height::256>> when height in 900..1000 -> <<height::256>> end]},
        {:aec_headers, [], [time_in_msecs: fn <<height::256>> -> @node_times[height] end]}
      ] do
        assert %{"data" => [oracle4, oracle3, oracle2, oracle1], "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/v2/oracles", limit: 4)
                 |> json_response(200)

        assert %{
                 "oracle" => ^id4,
                 "approximate_expire_time" => ^exp_time4,
                 "register_time" => ^reg_time4
               } = oracle4

        assert %{
                 "oracle" => ^id3,
                 "approximate_expire_time" => ^exp_time3,
                 "register_time" => ^reg_time3
               } = oracle3

        assert %{
                 "oracle" => ^id2,
                 "approximate_expire_time" => ^exp_time2,
                 "register_time" => ^reg_time2
               } = oracle2

        assert %{
                 "oracle" => ^id1,
                 "approximate_expire_time" => ^exp_time1,
                 "register_time" => ^reg_time1
               } = oracle1
      end
    end

    test "it retrieves only active oracles", %{
      conn: conn,
      store: store,
      register_times: [_rt1, _rt2, reg_time3, reg_time4],
      expiration_times: [_et1, _et2, exp_time3, exp_time4],
      encoded_pks: [_id1, _id2, id3, id4]
    } do
      with_mocks [
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {:aec_db, [],
         [get_header: fn <<height::256>> when height in 900..1000 -> <<height::256>> end]},
        {:aec_headers, [], [time_in_msecs: fn <<height::256>> -> @node_times[height] end]}
      ] do
        assert %{"data" => [oracle4, oracle3], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get("/v2/oracles", state: "active")
                 |> json_response(200)

        assert %{
                 "oracle" => ^id4,
                 "approximate_expire_time" => ^exp_time4,
                 "register_time" => ^reg_time4
               } = oracle4

        assert %{
                 "oracle" => ^id3,
                 "approximate_expire_time" => ^exp_time3,
                 "register_time" => ^reg_time3
               } = oracle3
      end
    end

    test "it retrieves only inactive oracles", %{
      conn: conn,
      store: store,
      register_times: [reg_time1, reg_time2 | _],
      expiration_times: [exp_time1, exp_time2 | _],
      encoded_pks: [id1, id2 | _]
    } do
      with_mocks [
        {Oracle, [:passthrough], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {:aec_db, [],
         [get_header: fn <<height::256>> when height in 900..1000 -> <<height::256>> end]},
        {:aec_headers, [], [time_in_msecs: fn <<height::256>> -> @node_times[height] end]}
      ] do
        assert %{"data" => [oracle2, oracle1], "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/v2/oracles", state: "inactive", limit: 2)
                 |> json_response(200)

        assert %{
                 "oracle" => ^id2,
                 "approximate_expire_time" => ^exp_time2,
                 "register_time" => ^reg_time2
               } = oracle2

        assert %{
                 "oracle" => ^id1,
                 "approximate_expire_time" => ^exp_time1,
                 "register_time" => ^reg_time1
               } = oracle1
      end
    end

    test "it displays tx hashes when tx_hash=true", %{conn: conn, store: store} do
      with_mocks [
        {Oracle, [], [oracle_tree!: fn _block_hash -> :aeo_state_tree.empty() end]},
        {:aeo_state_tree, [:passthrough], [get_oracle: fn _pk, _tree -> TS.core_oracle() end]},
        {:aec_db, [],
         [get_header: fn <<height::256>> when height in 900..1000 -> <<height::256>> end]},
        {:aec_headers, [], [time_in_msecs: fn <<height::256>> -> @node_times[height] end]}
      ] do
        assert %{"data" => [oracle2, oracle1], "next" => next_uri} =
                 conn
                 |> with_store(store)
                 |> get("/v2/oracles", tx_hash: "true", state: "inactive", limit: 2)
                 |> json_response(200)

        assert %{
                 "register_tx_hash" => register_tx_hash,
                 "extends" => [extends_tx_hash]
               } = oracle1

        assert ^register_tx_hash = Enc.encode(:tx_hash, <<1019::256>>)
        assert ^extends_tx_hash = Enc.encode(:tx_hash, <<1021::256>>)

        assert %{"register_tx_hash" => register_tx_hash, "extends" => []} = oracle2

        assert ^register_tx_hash = Enc.encode(:tx_hash, <<1020::256>>)

        assert %URI{
                 path: "/v2/oracles",
                 query: query
               } = URI.parse(next_uri)

        assert %{"cursor" => <<"950-", _rest::binary>>} = URI.decode_query(query)
      end
    end

    test "when both tx_hash and expand is sent, it displays error", %{conn: conn} do
      assert %{
               "error" =>
                 "invalid query: either `tx_hash` or `expand` parameters should be used, but not both."
             } =
               conn
               |> get("/v2/oracles", tx_hash: "true", expand: "true")
               |> json_response(400)
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
        |> Store.put(Model.Tx, Model.tx(index: 789, block_index: {1, 2}, id: tx_hash1))
        |> Store.put(
          Model.OracleQuery,
          Model.oracle_query(index: {oracle_pk, query_id2}, txi_idx: txi_idx2)
        )
        |> Store.put(Model.Tx, Model.tx(index: 791, block_index: {2, 2}, id: tx_hash2))
        |> Store.put(
          Model.OracleQuery,
          Model.oracle_query(index: {oracle_pk, query_id3}, txi_idx: txi_idx3)
        )
        |> Store.put(Model.Tx, Model.tx(index: 799, block_index: {3, 2}, id: tx_hash3))
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
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => [oracle1, oracle2], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/oracles/#{encoded_oracle_pk}/queries",
                   direction: "forward",
                   limit: 2
                 )
                 |> json_response(200)

        assert %{
                 "oracle_id" => ^encoded_oracle_pk,
                 "query_id" => ^encoded_query_id1,
                 "nonce" => 1,
                 "query_fee" => 11,
                 "sender_id" => ^encoded_account_id1,
                 "source_tx_type" => "OracleQueryTx",
                 "query" => "cXVlcnktMQ==",
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
                 "query" => "cXVlcnktMg==",
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
        |> Store.put(Model.Tx, Model.tx(index: 789, block_index: {1, 2}, id: tx_hash1))
        |> Store.put(Model.Tx, Model.tx(index: 989, block_index: {2, 1}))
        |> Store.put(
          Model.OracleQuery,
          Model.oracle_query(
            index: {oracle_pk, query_id2},
            txi_idx: txi_idx2,
            response_txi_idx: txi_idx5
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: 791, block_index: {2, 2}, id: tx_hash2))
        |> Store.put(Model.Tx, Model.tx(index: 991, block_index: {2, 3}))
        |> Store.put(
          Model.OracleQuery,
          Model.oracle_query(
            index: {oracle_pk, query_id3},
            txi_idx: txi_idx3,
            response_txi_idx: txi_idx6
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: 799, block_index: {2, 5}, id: tx_hash3))
        |> Store.put(Model.Tx, Model.tx(index: 999, block_index: {3, 0}))
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
        {:aec_db, [], [get_header: fn _key_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
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
                 "response" => "cmVzcG9uc2UtMQ==",
                 "block_time" => 123,
                 "height" => 2,
                 "query" => %{
                   "height" => 1,
                   "oracle_id" => ^encoded_oracle_pk,
                   "query_id" => ^encoded_query_id1,
                   "nonce" => 1,
                   "query_fee" => 11,
                   "sender_id" => ^encoded_account_id1,
                   "source_tx_type" => "OracleQueryTx",
                   "query" => "cXVlcnktMQ==",
                   "fee" => 11_111
                 }
               } = response1

        assert %{
                 "oracle_id" => ^encoded_oracle_pk,
                 "response" => "cmVzcG9uc2UtMg==",
                 "block_time" => 123,
                 "height" => 2,
                 "query" => %{
                   "height" => 2,
                   "oracle_id" => ^encoded_oracle_pk,
                   "query_id" => ^encoded_query_id2,
                   "nonce" => 2,
                   "query_fee" => 22,
                   "sender_id" => ^encoded_account_id2,
                   "source_tx_type" => "ContractCallTx",
                   "query" => "cXVlcnktMg==",
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
                 "height" => 3,
                 "query" => %{
                   "height" => 2,
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

  describe "oracle_extends" do
    test "it retrieves all oracle extends", %{conn: conn, store: store} do
      height = 707
      oracle_pk = <<1::256>>
      oracle_id = :aeser_id.create(:oracle, oracle_pk)
      encoded_oracle_pk = Enc.encode(:oracle_pubkey, oracle_pk)
      txi_idx1 = {789, -1}
      tx_hash1 = <<10::256>>
      txi_idx2 = {791, 3}
      tx_hash2 = <<11::256>>
      txi_idx3 = {799, -1}
      tx_hash3 = <<12::256>>
      block_hash1 = <<13::256>>
      block_index = {height, 200}

      {:ok, oracle_extend_aetx1} =
        :aeo_extend_tx.new(%{
          oracle_id: oracle_id,
          nonce: 1,
          oracle_ttl: {:delta, 111},
          fee: 11_111
        })

      {:ok, oracle_extend_aetx2} =
        :aeo_extend_tx.new(%{
          oracle_id: oracle_id,
          nonce: 2,
          oracle_ttl: {:delta, 222},
          fee: 22_222
        })

      {:ok, oracle_extend_aetx3} =
        :aeo_extend_tx.new(%{
          oracle_id: oracle_id,
          nonce: 3,
          oracle_ttl: {:delta, 333},
          fee: 33_333
        })

      {:oracle_extend_tx, oracle_extend_tx1} = :aetx.specialize_type(oracle_extend_aetx1)
      {:oracle_extend_tx, oracle_extend_tx2} = :aetx.specialize_type(oracle_extend_aetx2)
      {:oracle_extend_tx, oracle_extend_tx3} = :aetx.specialize_type(oracle_extend_aetx3)

      store =
        store
        |> Store.put(
          Model.ActiveOracle,
          Model.oracle(
            index: oracle_pk,
            extends: [{block_index, txi_idx3}, {block_index, txi_idx2}, {block_index, txi_idx1}]
          )
        )

      with_mocks [
        {DbUtil, [:passthrough],
         [
           read_node_tx_details: fn
             _state, ^txi_idx1 ->
               {oracle_extend_tx1, :oracle_extend_tx, tx_hash1, :oracle_extend_tx, block_hash1}

             _state, ^txi_idx2 ->
               {oracle_extend_tx2, :oracle_extend_tx, tx_hash2, :contract_call_tx, block_hash1}

             _state, ^txi_idx3 ->
               {oracle_extend_tx3, :oracle_extend_tx, tx_hash3, :oracle_extend_tx, block_hash1}
           end
         ]},
        {:aec_db, [], [get_header: fn _key_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => [extend1, extend2], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v3/oracles/#{encoded_oracle_pk}/extends",
                   direction: "forward",
                   limit: 2
                 )
                 |> json_response(200)

        assert %{
                 "height" => ^height,
                 "tx" => %{
                   "oracle_id" => ^encoded_oracle_pk,
                   "nonce" => 1,
                   "fee" => 11_111
                 },
                 "source_tx_type" => "OracleExtendTx"
               } = extend1

        assert %{
                 "height" => ^height,
                 "tx" => %{
                   "oracle_id" => ^encoded_oracle_pk,
                   "nonce" => 2,
                   "fee" => 22_222
                 },
                 "source_tx_type" => "ContractCallTx"
               } = extend2

        assert %{"data" => [extend3], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        assert %{
                 "height" => ^height,
                 "tx" => %{
                   "oracle_id" => ^encoded_oracle_pk,
                   "nonce" => 3,
                   "fee" => 33_333
                 },
                 "source_tx_type" => "OracleExtendTx"
               } = extend3
      end
    end

    test "cursor is invalid, it displays error", %{conn: conn} do
      encoded_oracle_id = Enc.encode(:oracle_pubkey, <<1::256>>)

      assert %{"error" => "invalid cursor: foo"} =
               conn
               |> get("/v3/oracles/#{encoded_oracle_id}/extends", cursor: "foo")
               |> json_response(400)
    end
  end

  test "oracle doesn't exist, it displays error", %{conn: conn} do
    encoded_oracle_id = Enc.encode(:oracle_pubkey, <<1::256>>)
    error = "not found: #{encoded_oracle_id}"

    assert %{"error" => ^error} =
             conn
             |> get("/v3/oracles/#{encoded_oracle_id}/extends")
             |> json_response(404)
  end
end
