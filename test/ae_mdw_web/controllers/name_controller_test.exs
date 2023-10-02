defmodule AeMdwWeb.NameControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Store
  alias AeMdw.Node.Db
  alias AeMdw.Validate
  alias AeMdw.TestSamples, as: TS
  alias AeMdw.Txs

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, name_tx: 3, tx: 3]
  import AeMdw.Db.ModelFixtures, only: [new_name: 0]
  import AeMdw.Util.Encoding

  import Mock

  require Model

  @default_limit 10

  setup _ do
    height_name = for i <- 100..121, into: %{}, do: {i, new_name()}

    {:ok, height_name: height_name}
  end

  describe "active_names" do
    test "renders active names with detailed info", %{conn: conn, store: store} do
      alice_name = "alice-in-chains.chain"
      bob_name = "boband-marley.chain"

      with_blockchain %{alice: 1_000, bob: 1_000},
        mb0: [
          tx1: name_tx(:name_claim_tx, :alice, alice_name),
          tx2: name_tx(:name_update_tx, :alice, alice_name)
        ],
        mb1: [
          tx3: name_tx(:name_claim_tx, :bob, bob_name)
        ],
        mb2: [
          tx4: name_tx(:name_update_tx, :bob, bob_name)
        ] do
        %{tx1: tx1, tx2: tx2, tx3: tx3, tx4: tx4} = transactions
        {:id, :account, alice_pk} = accounts[:alice]
        {:id, :account, bob_pk} = accounts[:bob]
        alice_id = encode(:account_pubkey, alice_pk)
        bob_id = encode(:account_pubkey, bob_pk)
        alice_oracle_id = encode(:oracle_pubkey, alice_pk)
        bob_oracle_id = encode(:oracle_pubkey, bob_pk)
        active_from = 10
        expire1 = 10_000
        expire2 = 10_001
        kb2 = blocks[2][:block]
        kb2_time = blocks[2][:time]
        last_gen = 3
        approx_expire_time1 = kb2_time + (expire2 - last_gen) * 180_000
        approx_expire_time2 = kb2_time + (expire1 - last_gen) * 180_000
        {:ok, key_hash2} = :aec_headers.hash_header(:aec_blocks.to_header(kb2))

        store =
          store
          |> Store.put(
            Model.ActiveName,
            Model.name(
              index: alice_name,
              owner: alice_pk,
              active: active_from,
              expire: expire1
            )
          )
          |> Store.put(
            Model.ActiveName,
            Model.name(
              index: bob_name,
              owner: bob_pk,
              active: active_from,
              expire: expire2
            )
          )
          |> Store.put(
            Model.NameClaim,
            Model.name_claim(index: {alice_name, active_from, {1, -1}})
          )
          |> Store.put(
            Model.NameTransfer,
            Model.name_transfer(index: {alice_name, active_from, {12, -1}})
          )
          |> Store.put(
            Model.NameUpdate,
            Model.name_update(index: {alice_name, active_from, {2, -1}})
          )
          |> Store.put(Model.NameClaim, Model.name_claim(index: {bob_name, active_from, {3, -1}}))
          |> Store.put(
            Model.NameTransfer,
            Model.name_transfer(index: {bob_name, active_from, {14, -1}})
          )
          |> Store.put(
            Model.NameUpdate,
            Model.name_update(index: {bob_name, active_from, {4, -1}})
          )
          |> Store.put(
            Model.ActiveNameExpiration,
            Model.expiration(index: {expire1, alice_name})
          )
          |> Store.put(
            Model.ActiveNameExpiration,
            Model.expiration(index: {expire2, bob_name})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1, id: :aetx_sign.hash(tx1), block_index: {1, 0})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 2, id: :aetx_sign.hash(tx2), block_index: {1, 0})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 3, id: :aetx_sign.hash(tx3), block_index: {1, 1})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 4, id: :aetx_sign.hash(tx4), block_index: {1, 2})
          )
          |> Store.put(Model.Block, Model.block(index: {last_gen, -1}, hash: key_hash2))

        assert %{"data" => [name1], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", state: "active", limit: 1)
                 |> json_response(200)

        assert %{
                 "name" => ^bob_name,
                 "active" => true,
                 "auction" => nil,
                 "info" => %{
                   "active_from" => ^active_from,
                   "auction_timeout" => 0,
                   "ownership" => %{"current" => ^bob_id, "original" => ^bob_id},
                   "pointers" => %{
                     "account_pubkey" => ^bob_id,
                     "oracle_pubkey" => ^bob_oracle_id
                   },
                   "revoke" => nil,
                   "transfers" => [14],
                   "updates" => [4],
                   "claims" => [3],
                   "expire_height" => ^expire2,
                   "approximate_expire_time" => ^approx_expire_time1
                 },
                 "previous" => [],
                 "status" => "name"
               } = name1

        assert %{"data" => [name2]} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        %{
          "name" => ^alice_name,
          "active" => true,
          "auction" => nil,
          "info" => %{
            "active_from" => ^active_from,
            "auction_timeout" => 0,
            "ownership" => %{"current" => ^alice_id, "original" => ^alice_id},
            "pointers" => %{
              "account_pubkey" => ^alice_id,
              "oracle_pubkey" => ^alice_oracle_id
            },
            "revoke" => nil,
            "transfers" => [12],
            "updates" => [2],
            "claims" => [1],
            "expire_height" => ^expire1,
            "approximate_expire_time" => ^approx_expire_time2
          },
          "previous" => [],
          "status" => "name"
        } = name2
      end
    end

    test "get active names with default limit", %{
      conn: conn,
      height_name: height_name,
      store: store
    } do
      key_hash = <<0::256>>

      store =
        height_name
        |> Enum.reduce(store, fn {expire, plain_name}, store ->
          height = expire

          name =
            Model.name(
              index: plain_name,
              active: expire - 10,
              expire: expire,
              revoke: nil,
              auction_timeout: 1
            )

          store
          |> Store.put(Model.ActiveName, name)
          |> Store.put(
            Model.ActiveNameExpiration,
            Model.expiration(index: {height - 1, height_name[height - 1]})
          )
          |> Store.put(Model.Block, Model.block(index: {height, -1}, hash: key_hash))
        end)
        |> Store.put(Model.ActiveNameExpiration, Model.expiration(index: {121, height_name[121]}))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mname -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => next} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", state: "active")
                 |> json_response(200)

        assert @default_limit = length(names)

        assert names ==
                 Enum.sort_by(
                   names,
                   fn %{"info" => %{"expire_height" => expire}} -> expire end,
                   :desc
                 )

        assert %{"data" => names_next, "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get(next)
                 |> json_response(200)

        assert @default_limit = length(names_next)

        assert names_next ==
                 Enum.sort_by(
                   names_next,
                   fn %{"info" => %{"expire_height" => expire}} -> expire end,
                   :desc
                 )
      end
    end

    test "get active names with parameters by=name, direction=forward and limit=3", %{
      conn: conn,
      store: store
    } do
      by = "name"
      direction = "forward"
      limit = 3
      key_hash = <<0::256>>

      store =
        1..11
        |> Enum.reduce(store, fn i, store ->
          name =
            Model.name(
              index: "#{i}.chain",
              active: true,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          Store.put(store, Model.ActiveName, name)
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))
        |> Store.put(Model.Block, Model.block(index: {2, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mname -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", state: "active", by: by, direction: direction, limit: limit)
                 |> json_response(200)

        plain_names = Enum.map(names, fn %{"name" => name} -> name end)
        assert ^limit = length(names)
        assert ^plain_names = Enum.sort(plain_names)

        assert %{"data" => names2} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        plain_names2 = Enum.map(names2, fn %{"name" => name} -> name end)
        assert ^limit = length(names2)
        assert ^plain_names2 = Enum.sort(plain_names2)
        assert List.last(plain_names) <= Enum.at(plain_names2, 0)
      end
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error = "invalid query: by=#{by}"

      assert %{"error" => ^error} =
               conn |> get("/v2/names", state: "active", by: by) |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid direction: #{direction}"

      assert %{"error" => ^error} =
               conn
               |> get("/v2/names", state: "active", by: by, direction: direction)
               |> json_response(400)
    end

    test "it renders active names with ga_meta transactions", %{conn: conn, store: store} do
      key_hash = <<0::256>>
      plain_name = "a.chain"

      name =
        Model.name(
          index: plain_name,
          active: true,
          expire: 1,
          revoke: {{0, 0}, {0, -1}},
          auction_timeout: 1
        )

      store =
        store
        |> Store.put(Model.ActiveNameExpiration, Model.expiration(index: {1, plain_name}))
        |> Store.put(Model.ActiveName, name)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))
        |> Store.put(Model.Block, Model.block(index: {4, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash ->
             %{"tx" => %{"tx" => %{"tx" => %{"pointers" => [], "account_id" => <<>>}}}}
           end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mname -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", state: "active")
                 |> json_response(200)

        assert 1 = length(names)
        assert [%{"name" => ^plain_name, "info" => %{"pointers" => %{}}}] = names
      end
    end
  end

  describe "inactive_names" do
    test "renders inactive names with detailed info", %{conn: conn, store: store} do
      alice_name = "aliceinchains.chain"
      bob_name = "bobandmarley.chain"

      with_blockchain %{alice: 1_000, bob: 1_000},
        mb0: [
          tx1: name_tx(:name_claim_tx, :alice, alice_name),
          tx2: name_tx(:name_revoke_tx, :alice, alice_name)
        ],
        mb1: [
          tx3: name_tx(:name_claim_tx, :bob, bob_name)
        ],
        mb2: [
          tx4: name_tx(:name_update_tx, :bob, bob_name),
          tx5: name_tx(:name_revoke_tx, :bob, bob_name)
        ] do
        %{tx1: tx1, tx2: tx2, tx3: tx3, tx4: tx4, tx5: tx5} = transactions
        {:id, :account, alice_pk} = accounts[:alice]
        {:id, :account, bob_pk} = accounts[:bob]
        alice_id = encode(:account_pubkey, alice_pk)
        bob_id = encode(:account_pubkey, bob_pk)
        bob_oracle_id = encode(:oracle_pubkey, bob_pk)
        active_from = 10
        expire1 = 10_000
        expire2 = 10_001
        kb_time = blocks[0][:time]
        last_gen = 3
        approx_expire_time1 = kb_time + (expire1 - last_gen) * 180_000
        approx_expire_time2 = kb_time + (expire2 - last_gen) * 180_000

        {:ok, key_hash} =
          blocks[0][:block] |> :aec_blocks.to_header() |> :aec_headers.hash_header()

        store =
          store
          |> Store.put(
            Model.InactiveName,
            Model.name(
              index: alice_name,
              owner: alice_pk,
              active: active_from,
              revoke: {{10, 0}, {2, -1}},
              expire: expire1
            )
          )
          |> Store.put(
            Model.NameClaim,
            Model.name_claim(index: {alice_name, active_from, {1, -1}})
          )
          |> Store.put(
            Model.InactiveName,
            Model.name(
              index: bob_name,
              owner: bob_pk,
              active: active_from,
              revoke: {{10, 2}, {5, -1}},
              expire: expire2
            )
          )
          |> Store.put(
            Model.NameUpdate,
            Model.name_update(index: {bob_name, active_from, {4, -1}})
          )
          |> Store.put(Model.NameClaim, Model.name_claim(index: {bob_name, active_from, {3, -1}}))
          |> Store.put(
            Model.InactiveNameExpiration,
            Model.expiration(index: {2, alice_name})
          )
          |> Store.put(
            Model.InactiveNameExpiration,
            Model.expiration(index: {5, bob_name})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1, id: :aetx_sign.hash(tx1), block_index: {1, 0})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 2, id: :aetx_sign.hash(tx2), block_index: {1, 0})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 3, id: :aetx_sign.hash(tx3), block_index: {1, 1})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 4, id: :aetx_sign.hash(tx4), block_index: {1, 2})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 5, id: :aetx_sign.hash(tx5), block_index: {1, 2})
          )
          |> Store.put(Model.Block, Model.block(index: {last_gen, -1}, hash: key_hash))

        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", state: "inactive")
                 |> json_response(200)

        assert [
                 %{
                   "name" => ^bob_name,
                   "active" => false,
                   "auction" => nil,
                   "info" => %{
                     "active_from" => ^active_from,
                     "auction_timeout" => 0,
                     "ownership" => %{"current" => ^bob_id, "original" => ^bob_id},
                     "pointers" => %{
                       "account_pubkey" => ^bob_id,
                       "oracle_pubkey" => ^bob_oracle_id
                     },
                     "revoke" => 5,
                     "transfers" => [],
                     "updates" => [4],
                     "claims" => [3],
                     "expire_height" => ^expire2,
                     "approximate_expire_time" => ^approx_expire_time2
                   },
                   "previous" => [],
                   "status" => "name"
                 },
                 %{
                   "name" => ^alice_name,
                   "active" => false,
                   "auction" => nil,
                   "info" => %{
                     "active_from" => ^active_from,
                     "auction_timeout" => 0,
                     "ownership" => %{"current" => ^alice_id, "original" => ^alice_id},
                     "pointers" => %{},
                     "revoke" => 2,
                     "transfers" => [],
                     "updates" => [],
                     "claims" => [1],
                     "expire_height" => ^expire1,
                     "approximate_expire_time" => ^approx_expire_time1
                   },
                   "previous" => [],
                   "status" => "name"
                 }
               ] = names
      end
    end

    test "get inactive names with default limit", %{conn: conn, store: store} do
      key_hash = <<0::256>>

      store =
        1..21
        |> Enum.reduce(store, fn i, store ->
          plain_name = "#{i}.chain"

          name =
            Model.name(
              index: plain_name,
              active: true,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.InactiveNameExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(Model.InactiveName, name)
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mname -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => next} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", state: "inactive")
                 |> json_response(200)

        assert @default_limit = length(names)

        assert %{"data" => next_names, "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get(next)
                 |> json_response(200)

        assert @default_limit = length(next_names)
      end
    end

    test "get inactive names with limit=6", %{conn: conn, store: store} do
      limit = 6
      key_hash = <<0::256>>

      store =
        1..21
        |> Enum.reduce(store, fn i, store ->
          plain_name = "#{i}.chain"

          name =
            Model.name(
              index: plain_name,
              active: true,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.InactiveNameExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(Model.InactiveName, name)
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {
          Name,
          [],
          [
            pointers: fn _state, _mnme -> %{} end,
            ownership: fn _state, _mname -> %{current: nil, original: nil} end,
            stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
          ]
        },
        {:aec_db, [], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", state: "inactive", limit: limit)
                 |> json_response(200)

        assert ^limit = length(names)
      end
    end

    test "get inactive names with parameters by=name, direction=forward and limit=3", %{
      conn: conn,
      store: store
    } do
      by = "name"
      direction = "forward"
      limit = 3
      block_hash1 = <<0::256>>
      block_hash2 = <<1::256>>

      name =
        Model.name(
          active: false,
          expire: 1,
          revoke: {{0, 0}, {0, -1}},
          auction_timeout: 1
        )

      store =
        store
        |> Store.put(Model.InactiveName, Model.name(name, index: "a.chain"))
        |> Store.put(Model.InactiveName, Model.name(name, index: "aa.chain"))
        |> Store.put(Model.InactiveName, Model.name(name, index: "aaa.chain"))
        |> Store.put(Model.InactiveName, Model.name(name, index: "aaaa.chain"))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: block_hash1))
        |> Store.put(Model.Block, Model.block(index: {2, -1}, hash: block_hash2))

      with_mocks [
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", state: "inactive", by: by, direction: direction, limit: limit)
                 |> json_response(200)

        assert ^limit = length(names)
      end
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error = "invalid query: by=#{by}"

      assert %{"error" => ^error} = conn |> get("/v2/names", by: by) |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid direction: #{direction}"

      assert %{"error" => ^error} =
               conn
               |> get("/v2/names", state: "inactive", by: by, direction: direction)
               |> json_response(400)
    end
  end

  describe "auction" do
    test "get last bid for a name in auction", %{conn: conn, store: store} do
      {_exp, plain_name} = expiration_key = TS.name_expiration_key(0)

      with_blockchain %{alice: 1_000, bob: 1_000},
        mb0: [
          tx1: name_tx(:name_claim_tx, :alice, plain_name)
        ],
        mb1: [
          tx2: name_tx(:name_claim_tx, :bob, plain_name)
        ] do
        %{tx1: tx1, tx2: tx2} = transactions
        %{mb0: %{block: mb0}} = blocks
        {:ok, hash0} = mb0 |> :aec_blocks.to_header() |> :aec_headers.hash_header()

        m_auction =
          Model.auction_bid(
            index: plain_name,
            block_index_txi_idx: {{0, 0}, {1, -1}},
            expire_height: 0
          )

        store =
          store
          |> Store.put(Model.AuctionExpiration, Model.expiration(index: expiration_key))
          |> Store.put(Model.AuctionBid, m_auction)
          |> Store.put(
            Model.AuctionBidClaim,
            Model.auction_bid_claim(index: {plain_name, 0, {1, -1}})
          )
          |> Store.put(
            Model.AuctionBidClaim,
            Model.auction_bid_claim(index: {plain_name, 0, {2, -1}})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1, block_index: {0, 1}, id: :aetx_sign.hash(tx1))
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 2, block_index: {1, 0}, id: :aetx_sign.hash(tx2))
          )
          |> Store.put(Model.Block, Model.block(index: {0, -1}, hash: hash0))
          |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: hash0))

        {:id, :account, bob_pk} = accounts[:bob]
        bob_id = encode(:account_pubkey, bob_pk)
        %{hash: mb_hash} = blocks[:mb1]
        tx_hash = encode(:tx_hash, :aetx_sign.hash(tx2))

        assert %{
                 "active" => false,
                 "info" => %{
                   "auction_end" => 0,
                   "bids" => [2, 1],
                   "last_bid" => %{
                     "block_hash" => ^mb_hash,
                     "hash" => ^tx_hash,
                     "signatures" => [],
                     "tx" => %{
                       "account_id" => ^bob_id,
                       "name" => ^plain_name,
                       "type" => "NameClaimTx",
                       "version" => 2
                     },
                     "tx_index" => 2
                   }
                 },
                 "name" => ^plain_name,
                 "previous" => [],
                 "status" => "auction"
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/#{plain_name}/auction")
                 |> json_response(200)
      end
    end

    test "get expanded bids for a name in auction", %{conn: conn, store: store} do
      {_exp, plain_name} = expiration_key = TS.name_expiration_key(0)

      with_blockchain %{alice: 1_000, bob: 1_000},
        mb0: [
          tx1: name_tx(:name_claim_tx, :alice, plain_name)
        ],
        mb1: [
          tx2: name_tx(:name_claim_tx, :bob, plain_name)
        ] do
        %{tx1: tx1, tx2: tx2} = transactions

        {:ok, key_hash} =
          blocks[0][:block] |> :aec_blocks.to_header() |> :aec_headers.hash_header()

        m_auction =
          Model.auction_bid(
            index: plain_name,
            block_index_txi_idx: {{0, 0}, {1, -1}},
            expire_height: 0
          )

        store =
          store
          |> Store.put(Model.AuctionExpiration, Model.expiration(index: expiration_key))
          |> Store.put(Model.AuctionBid, m_auction)
          |> Store.put(
            Model.AuctionBidClaim,
            Model.auction_bid_claim(index: {plain_name, 0, {2, -1}})
          )
          |> Store.put(
            Model.AuctionBidClaim,
            Model.auction_bid_claim(index: {plain_name, 0, {1, -1}})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1, id: :aetx_sign.hash(tx1), block_index: {0, 1})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 2, id: :aetx_sign.hash(tx2), block_index: {1, 0})
          )
          |> Store.put(Model.Block, Model.block(index: {0, -1}, hash: key_hash))
          |> Store.put(Model.Block, Model.block(index: {3, -1}, hash: key_hash))

        {:id, :account, alice_pk} = accounts[:alice]
        {:id, :account, bob_pk} = accounts[:bob]
        alice_id = encode(:account_pubkey, alice_pk)
        bob_id = encode(:account_pubkey, bob_pk)
        %{hash: mb_hash0} = blocks[:mb0]
        %{hash: mb_hash1} = blocks[:mb1]
        tx_hash1 = encode(:tx_hash, :aetx_sign.hash(tx1))
        tx_hash2 = encode(:tx_hash, :aetx_sign.hash(tx2))

        assert %{
                 "active" => false,
                 "info" => %{
                   "auction_end" => 0,
                   "bids" => [
                     %{
                       "block_hash" => ^mb_hash1,
                       "block_height" => 1,
                       "hash" => ^tx_hash2,
                       "tx" => %{
                         "account_id" => ^bob_id,
                         "name" => ^plain_name,
                         "type" => "NameClaimTx"
                       },
                       "tx_index" => 2
                     },
                     %{
                       "block_hash" => ^mb_hash0,
                       "block_height" => 0,
                       "hash" => ^tx_hash1,
                       "tx" => %{
                         "account_id" => ^alice_id,
                         "name" => ^plain_name,
                         "type" => "NameClaimTx"
                       },
                       "tx_index" => 1
                     }
                   ],
                   "last_bid" => %{
                     "block_hash" => ^mb_hash1,
                     "hash" => ^tx_hash2,
                     "signatures" => [],
                     "tx" => %{
                       "account_id" => ^bob_id,
                       "name" => ^plain_name,
                       "type" => "NameClaimTx",
                       "version" => 2
                     },
                     "tx_index" => 2
                   }
                 },
                 "name" => ^plain_name,
                 "previous" => [],
                 "status" => "auction"
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/#{plain_name}/auction", expand: true)
                 |> json_response(200)
      end
    end

    test "renders 404 when the name is not in auction", %{conn: conn, store: store} do
      plain_name = "no-auction.chain"
      error = "not found: #{plain_name}"

      name_hash =
        case :aens.get_name_hash(plain_name) do
          {:ok, name_id_bin} -> :aeser_api_encoder.encode(:name, name_id_bin)
          _error -> nil
        end

      active_from = 11
      expire = 100
      owner_pk = <<1::256>>

      active_name =
        Model.name(
          index: plain_name,
          active: active_from,
          expire: expire,
          revoke: nil,
          owner: owner_pk
        )

      store =
        store
        |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
        |> Store.put(Model.ActiveName, active_name)
        |> Store.put(
          Model.ActiveNameActivation,
          Model.activation(index: {active_from, plain_name})
        )
        |> Store.put(
          Model.ActiveNameExpiration,
          Model.expiration(index: {expire, plain_name})
        )
        |> Store.put(Model.ActiveNameOwner, Model.owner(index: {owner_pk, plain_name}))

      assert %{"error" => ^error} =
               conn
               |> with_store(store)
               |> get("/v2/names/#{plain_name}/auction")
               |> json_response(404)
    end
  end

  describe "auctions" do
    test "get auctions with default limit", %{conn: conn, store: store} do
      key_hash = <<0::256>>
      kb_time = 123
      last_gen = 4
      approx_expire_time4 = kb_time + (4 - last_gen) * 180_000

      store =
        1..21
        |> Enum.reduce(store, fn i, store ->
          plain_name = "#{i}.chain"

          auction =
            Model.auction_bid(
              index: plain_name,
              block_index_txi_idx: {{0, 1}, {0, -1}},
              expire_height: i
            )

          store
          |> Store.put(Model.AuctionBid, auction)
          |> Store.put(Model.AuctionExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(Model.Block, Model.block(index: {i, -1}, hash: key_hash))
          |> Store.put(
            Model.AuctionBidClaim,
            Model.auction_bid_claim(index: {plain_name, i, {4, -1}})
          )
          |> Store.put(
            Model.PreviousName,
            Model.previous_name(
              index: {i, plain_name},
              name: Model.name(index: plain_name)
            )
          )
        end)
        |> Store.put(Model.Block, Model.block(index: {last_gen, -1}, hash: key_hash))
        |> Store.put(Model.Block, Model.block(index: {0, 1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}, "tx_index" => 122} end
         ]},
        {Db, [],
         [
           proto_vsn: fn _height -> 1 end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> kb_time end]}
      ] do
        assert %{"data" => auction_bids, "next" => next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names/auctions", direction: "forward")
                 |> json_response(200)

        assert @default_limit = length(auction_bids)
        refute is_nil(next)

        assert %{
                 "name" => "1.chain",
                 "approximate_expire_time" => 123,
                 "last_bid" => last_bid
               } = Enum.at(auction_bids, 0)

        refute Map.has_key?(last_bid, "tx_index")

        assert %{
                 "name" => "5.chain",
                 "approximate_expire_time" => ^approx_expire_time4
               } = Enum.at(auction_bids, 4)

        assert %{"data" => auction_bids2} =
                 conn
                 |> with_store(store)
                 |> get(next)
                 |> json_response(200)

        assert @default_limit = length(auction_bids2)
      end
    end

    test "when v2, it gets auctions with default limit", %{conn: conn, store: store} do
      key_hash = <<0::256>>
      kb_time = 123
      last_gen = 4
      approx_expire_time4 = kb_time + (4 - last_gen) * 180_000

      store =
        1..21
        |> Enum.reduce(store, fn i, store ->
          plain_name = "#{i}.chain"

          auction =
            Model.auction_bid(
              index: plain_name,
              block_index_txi_idx: {{0, 1}, {0, -1}},
              expire_height: i
            )

          store
          |> Store.put(Model.AuctionBid, auction)
          |> Store.put(Model.AuctionExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(
            Model.AuctionBidClaim,
            Model.auction_bid_claim(index: {plain_name, i, {4, -1}})
          )
          |> Store.put(Model.Block, Model.block(index: {i, -1}, hash: key_hash))
        end)
        |> Store.put(Model.Block, Model.block(index: {last_gen, -1}, hash: key_hash))
        |> Store.put(Model.Block, Model.block(index: {0, 1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Db, [],
         [
           proto_vsn: fn _height -> 1 end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> kb_time end]}
      ] do
        assert %{"data" => auction_bids, "next" => next} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/auctions", direction: "forward")
                 |> json_response(200)

        assert @default_limit = length(auction_bids)
        refute is_nil(next)

        assert %{
                 "info" => %{"approximate_expire_time" => 123}
               } = Enum.at(auction_bids, 0)

        assert %{
                 "info" => %{"approximate_expire_time" => ^approx_expire_time4}
               } = Enum.at(auction_bids, 4)

        assert %{"data" => auction_bids2} =
                 conn
                 |> with_store(store)
                 |> get(next)
                 |> json_response(200)

        assert @default_limit = length(auction_bids2)
      end
    end

    test "get auctions with parameters by=expiration, direction=forward and limit=3", %{
      conn: conn,
      store: store
    } do
      by = "expiration"
      direction = "forward"
      limit = 3
      key_hash = <<0::256>>

      store =
        1..21
        |> Enum.reduce(store, fn i, store ->
          plain_name = "#{i}.chain"

          auction =
            Model.auction_bid(
              index: plain_name,
              block_index_txi_idx: {{0, 1}, {0, -1}},
              expire_height: 0
            )

          store
          |> Store.put(Model.AuctionBid, auction)
          |> Store.put(Model.AuctionExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(
            Model.AuctionBidClaim,
            Model.auction_bid_claim(index: {plain_name, 0, {4, -1}})
          )
        end)
        |> Store.put(Model.Block, Model.block(index: {0, -1}, hash: key_hash))
        |> Store.put(Model.Block, Model.block(index: {4, -1}, hash: key_hash))
        |> Store.put(Model.Block, Model.block(index: {0, 1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Db, [],
         [
           proto_vsn: fn _height -> 1 end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => [auction_bid1 | _rest] = auctions} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/auctions", by: by, direction: direction, limit: limit)
                 |> json_response(200)

        assert %{
                 "info" => %{"approximate_expire_time" => 123}
               } = auction_bid1

        assert ^limit = length(auctions)
      end
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error = "invalid query: by=#{by}"

      assert %{"error" => ^error} =
               conn |> get("/v2/names/auctions", by: by) |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid direction: #{direction}"

      assert %{"error" => ^error} =
               conn
               |> get("/v2/names/auctions", by: by, direction: direction)
               |> json_response(400)
    end
  end

  describe "names" do
    test "get active and inactive names, except those in auction, with default limit", %{
      conn: conn,
      store: store
    } do
      key_hash = <<0::256>>

      store =
        1..11
        |> Enum.reduce(store, fn i, store ->
          plain_name = "#{i}.chain"

          name =
            Model.name(
              index: plain_name,
              active: true,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.ActiveName, name)
          |> Store.put(Model.ActiveNameExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(Model.Block, Model.block(index: {i, -1}, hash: key_hash))
        end)

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names")
                 |> json_response(200)

        assert @default_limit = length(names)
      end
    end

    test "on v2, it gets active and inactive names, except those in auction, with default limit",
         %{
           conn: conn,
           store: store
         } do
      key_hash = <<0::256>>

      store =
        1..11
        |> Enum.reduce(store, fn i, store ->
          plain_name = "#{i}.chain"

          name =
            Model.name(
              index: plain_name,
              active: true,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.ActiveName, name)
          |> Store.put(Model.ActiveNameExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(Model.Block, Model.block(index: {i, -1}, hash: key_hash))
        end)

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/names")
                 |> json_response(200)

        assert @default_limit = length(names)
      end
    end

    test "get active and inactive names, except those in auction, with limit=2", %{
      conn: conn,
      store: store
    } do
      limit = 2
      key_hash = <<0::256>>

      store =
        1..11
        |> Enum.reduce(store, fn i, store ->
          plain_name = "#{i}.chain"

          name =
            Model.name(
              index: plain_name,
              active: true,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.ActiveName, name)
          |> Store.put(Model.ActiveNameExpiration, Model.expiration(index: {i, plain_name}))
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mname -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", limit: limit)
                 |> json_response(200)

        assert ^limit = length(names)
      end
    end

    test "gets names filtered by owner id and state ordered by deactivation", %{
      conn: conn,
      store: store
    } do
      owner_id = "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
      owner_pk = Validate.id!(owner_id)
      other_pk = :crypto.strong_rand_bytes(32)
      first_name = TS.plain_name(4)
      not_owned_name = "o2#{first_name}"
      second_name = "o1#{first_name}"
      third_name = "o3#{first_name}"
      exp_height = 123
      key_hash = <<0::256>>

      inactive_name =
        Model.name(
          index: first_name,
          active: false,
          expire: 3,
          revoke: nil,
          owner: owner_pk,
          auction_timeout: 1
        )

      active_name = Model.name(inactive_name, index: third_name)

      store =
        store
        |> Store.put(Model.InactiveName, inactive_name)
        |> Store.put(
          Model.InactiveNameOwnerDeactivation,
          Model.owner_deactivation(index: {owner_pk, exp_height, first_name})
        )
        |> Store.put(Model.InactiveName, Model.name(inactive_name, index: second_name))
        |> Store.put(
          Model.InactiveNameOwnerDeactivation,
          Model.owner_deactivation(index: {owner_pk, exp_height + 1, second_name})
        )
        |> Store.put(
          Model.InactiveName,
          Model.name(inactive_name, index: not_owned_name, owner: other_pk)
        )
        |> Store.put(
          Model.InactiveNameOwnerDeactivation,
          Model.owner_deactivation(index: {other_pk, exp_height + 2, not_owned_name})
        )
        |> Store.put(Model.ActiveName, active_name)
        |> Store.put(Model.ActiveNameOwner, Model.owner(index: {owner_pk, third_name}))
        |> Store.put(
          Model.ActiveNameOwnerDeactivation,
          Model.owner_deactivation(index: {owner_pk, exp_height + 3, third_name})
        )
        |> Store.put(Model.Block, Model.block(index: {2, -1}, hash: key_hash))

      with_mocks [
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => [name1, name2, name3], "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", direction: "forward", owned_by: owner_id)
                 |> json_response(200)

        assert %{"name" => ^first_name} = name1
        assert %{"name" => ^second_name} = name2
        assert %{"name" => ^third_name} = name3

        assert %{"data" => [name1, name2], "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names",
                   direction: "forward",
                   limit: 3,
                   owned_by: owner_id,
                   state: "inactive"
                 )
                 |> json_response(200)

        assert %{"name" => ^first_name} = name1
        assert %{"name" => ^second_name} = name2
      end
    end

    test "get active and inactive names, except those in auction, with parameters by=name, direction=forward and limit=4",
         %{conn: conn, store: store} do
      limit = 4
      by = "name"
      direction = "forward"
      key_hash = <<0::256>>

      store =
        1..5
        |> Enum.reduce(store, fn i, store ->
          plain_name = "#{i}.chain"

          name =
            Model.name(
              index: plain_name,
              active: Enum.random(1000..9999),
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          Store.put(store, Model.ActiveName, name)
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/names?by=#{by}&direction=#{direction}&limit=#{limit}")
                 |> json_response(200)

        plain_names = Enum.map(names, & &1["name"])
        assert ^plain_names = Enum.sort(plain_names)
        assert ^limit = length(names)
      end
    end

    test "get active names with parameters by=activation, direction=forward and limit=9",
         %{conn: conn, store: store} do
      limit = 9
      by = "activation"
      direction = "forward"
      key_hash = <<0::256>>

      store =
        1..11
        |> Enum.reduce(store, fn i, store ->
          plain_name = "#{i}.chain"

          name =
            Model.name(
              index: plain_name,
              active: i,
              expire: i + 10
            )

          store
          |> Store.put(Model.ActiveName, name)
          |> Store.put(Model.ActiveNameActivation, Model.activation(index: {i, plain_name}))
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]},
        {:aec_db, [], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/names", state: "active", by: by, direction: direction, limit: limit)
                 |> json_response(200)

        heights = Enum.map(names, & &1["info"]["active_from"])

        assert ^heights = Enum.sort(heights)
        assert ^limit = length(names)
      end
    end

    test "get inactive names for given account/owner", %{conn: conn, store: store} do
      owner_id = "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
      owner_pk = Validate.id!(owner_id)
      other_pk = :crypto.strong_rand_bytes(32)
      limit = 2
      first_name = TS.plain_name(4)
      not_owned_name = "o2#{first_name}"
      second_name = "o1#{first_name}"
      key_hash = <<0::256>>

      m_name =
        Model.name(
          index: first_name,
          active: false,
          expire: 3,
          revoke: nil,
          owner: owner_pk,
          auction_timeout: 1
        )

      store =
        [
          {first_name, owner_pk},
          {second_name, owner_pk},
          {not_owned_name, other_pk}
        ]
        |> Enum.reduce(store, fn {plain_name, owner_pk}, store ->
          m_name = Model.name(m_name, index: plain_name, owner: owner_pk)

          store
          |> Store.put(Model.InactiveName, m_name)
          |> Store.put(Model.InactiveNameOwner, Model.owner(index: {owner_pk, plain_name}))
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname ->
             orig = {:id, :account, owner_pk}
             %{current: orig, original: orig}
           end
         ]},
        {:aec_db, [], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => owned_names} =
                 conn
                 |> with_store(store)
                 |> get("/names",
                   owned_by: owner_id,
                   by: "name",
                   state: "inactive",
                   limit: limit
                 )
                 |> json_response(200)

        assert length(owned_names) == limit

        assert Enum.all?(owned_names, fn %{"name" => plain_name} ->
                 plain_name in [first_name, second_name]
               end)
      end
    end

    test "get both active and inactive names for given account/owner", %{conn: conn, store: store} do
      owner_id = "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
      owner_pk = Validate.id!(owner_id)
      other_pk = :crypto.strong_rand_bytes(32)
      first_name = TS.plain_name(4)
      not_owned_name = "o2#{first_name}"
      second_name = "o1#{first_name}"
      third_name = "o3#{first_name}"
      key_hash = <<0::256>>

      inactive_name =
        Model.name(
          index: first_name,
          active: false,
          expire: 3,
          revoke: nil,
          owner: owner_pk,
          auction_timeout: 1
        )

      active_name = Model.name(inactive_name, index: third_name)

      store =
        store
        |> Store.put(Model.InactiveName, inactive_name)
        |> Store.put(Model.InactiveName, Model.name(inactive_name, index: second_name))
        |> Store.put(
          Model.InactiveName,
          Model.name(inactive_name, index: not_owned_name, owner: other_pk)
        )
        |> Store.put(Model.InactiveNameOwner, Model.owner(index: {owner_pk, first_name}))
        |> Store.put(Model.InactiveNameOwner, Model.owner(index: {owner_pk, second_name}))
        |> Store.put(Model.InactiveNameOwner, Model.owner(index: {other_pk, not_owned_name}))
        |> Store.put(Model.ActiveName, active_name)
        |> Store.put(Model.ActiveNameOwner, Model.owner(index: {owner_pk, third_name}))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname ->
             orig = {:id, :account, owner_pk}
             %{current: orig, original: orig}
           end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => owned_names} =
                 conn
                 |> with_store(store)
                 |> get("/names",
                   owned_by: owner_id,
                   by: "name",
                   limit: 3
                 )
                 |> json_response(200)

        assert [^third_name, ^second_name, ^first_name] =
                 Enum.map(owned_names, fn %{"name" => name} -> name end)
      end
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error = "invalid query: by=#{by}"

      assert %{"error" => ^error} = conn |> get("/names?by=#{by}") |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid direction: #{direction}"

      assert %{"error" => ^error} =
               conn |> get("/names?by=#{by}&direction=#{direction}") |> json_response(400)
    end

    test "renders error when parameter owned_by is not an address", %{conn: conn} do
      owned_by = "invalid_address"
      error = "invalid id: #{owned_by}"

      assert %{"error" => ^error} =
               conn |> get("/names?owned_by=#{owned_by}") |> json_response(400)
    end
  end

  describe "name" do
    test "get active name info with pointers", %{conn: conn, store: store} do
      name = "bigname123456.chain"

      with_blockchain %{alice: 1_000},
        mb: [
          tx1: name_tx(:name_claim_tx, :alice, name),
          tx2: name_tx(:name_update_tx, :alice, name)
        ] do
        %{txs: [tx1, tx2]} = blocks[:mb]
        {:id, :account, alice_pk} = accounts[:alice]
        alice_id = encode(:account_pubkey, alice_pk)
        oracle_id = encode(:oracle_pubkey, alice_pk)
        active_from = 10
        expire = 10_000

        store =
          store
          |> Store.put(
            Model.ActiveName,
            Model.name(
              index: name,
              owner: alice_pk,
              active: active_from,
              expire: expire
            )
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1, id: :aetx_sign.hash(tx1), block_index: {1, 1})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 2, id: :aetx_sign.hash(tx2), block_index: {1, 1})
          )
          |> Store.put(Model.NameClaim, Model.name_claim(index: {name, active_from, {1, -1}}))
          |> Store.put(Model.NameUpdate, Model.name_update(index: {name, active_from, {2, -1}}))

        assert %{
                 "name" => ^name,
                 "active" => true,
                 "auction" => nil,
                 "info" => %{
                   "active_from" => ^active_from,
                   "auction_timeout" => 0,
                   "ownership" => %{"current" => ^alice_id, "original" => ^alice_id},
                   "pointers" => %{
                     "account_pubkey" => ^alice_id,
                     "oracle_pubkey" => ^oracle_id
                   },
                   "revoke" => nil,
                   "transfers" => [],
                   "updates" => [2],
                   "claims" => [1],
                   "expire_height" => ^expire
                 },
                 "previous" => [],
                 "status" => "name"
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/#{name}")
                 |> json_response(200)
      end
    end

    test "get name claimed with ga_meta_tx", %{conn: conn, store: store} do
      buyer_pk = TS.address(0)
      owner_pk = TS.address(1)
      buyer_id = encode(:account_pubkey, buyer_pk)
      owner_id = encode(:account_pubkey, owner_pk)
      plain_name = "gametaclaimed.chain"
      active_height = 10

      {:ok, name_claim_tx} =
        :aens_claim_tx.new(%{
          account_id: :aeser_id.create(:account, buyer_pk),
          nonce: 1,
          name: plain_name,
          name_salt: 123_456,
          fee: 5_000
        })

      with_blockchain %{ga: 1_000},
        mb: [
          ga_tx: tx(:ga_meta_tx, :ga, %{tx: :aetx_sign.new(name_claim_tx, [])})
        ] do
        %{txs: [tx]} = blocks[:mb]

        store =
          store
          |> Store.put(
            Model.ActiveName,
            Model.name(
              index: plain_name,
              owner: owner_pk,
              active: active_height,
              expire: 10_000
            )
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1, id: :aetx_sign.hash(tx), block_index: {1, 1})
          )
          |> Store.put(
            Model.NameTransfer,
            Model.name_transfer(index: {plain_name, active_height, {2, -1}})
          )
          |> Store.put(
            Model.NameClaim,
            Model.name_claim(index: {plain_name, active_height, {1, -1}})
          )

        assert %{
                 "name" => ^plain_name,
                 "active" => true,
                 "auction" => nil,
                 "info" => %{
                   "ownership" => %{"current" => ^owner_id, "original" => ^buyer_id},
                   "revoke" => nil,
                   "transfers" => [2],
                   "updates" => [],
                   "claims" => [1]
                 },
                 "previous" => [],
                 "status" => "name"
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/#{plain_name}")
                 |> json_response(200)
      end
    end

    test "get name claimed with paying_for_tx", %{conn: conn, store: store} do
      buyer_pk = TS.address(2)
      owner_pk = TS.address(3)
      buyer_id = encode(:account_pubkey, buyer_pk)
      owner_id = encode(:account_pubkey, owner_pk)
      plain_name = "payinforclaimed.chain"

      {:ok, name_claim_tx} =
        :aens_claim_tx.new(%{
          account_id: :aeser_id.create(:account, buyer_pk),
          nonce: 1,
          name: plain_name,
          name_salt: 123_456,
          fee: 5_000
        })

      with_blockchain %{pf: 1_000},
        mb: [
          pf_tx: tx(:paying_for_tx, :pf, %{tx: :aetx_sign.new(name_claim_tx, [])})
        ] do
        %{txs: [tx]} = blocks[:mb]

        store =
          store
          |> Store.put(
            Model.ActiveName,
            Model.name(
              index: plain_name,
              owner: owner_pk,
              active: 10,
              expire: 10_000
            )
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1, id: :aetx_sign.hash(tx), block_index: {1, 1})
          )
          |> Store.put(Model.NameClaim, Model.name_claim(index: {plain_name, 10, {1, -1}}))
          |> Store.put(Model.NameTransfer, Model.name_transfer(index: {plain_name, 10, {2, -1}}))

        assert %{
                 "name" => ^plain_name,
                 "active" => true,
                 "auction" => nil,
                 "info" => %{
                   "ownership" => %{"current" => ^owner_id, "original" => ^buyer_id},
                   "revoke" => nil,
                   "transfers" => [2],
                   "updates" => [],
                   "claims" => [1]
                 },
                 "previous" => [],
                 "status" => "name"
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/#{plain_name}")
                 |> json_response(200)
      end
    end

    test "get inactive name in auction", %{conn: conn, store: store} do
      name = "alice.chain"

      with_blockchain %{alice: 1_000},
        mb: [
          tx: name_tx(:name_claim_tx, :alice, name)
        ] do
        %{txs: [tx], block: mb_block} = blocks[:mb]
        {:ok, mb_hash} = mb_block |> :aec_blocks.to_header() |> :aec_headers.hash_header()
        block_time = mb_block |> :aec_blocks.to_header() |> :aec_headers.time_in_msecs()
        {:id, :account, alice_pk} = accounts[:alice]
        owner_id = encode(:account_pubkey, alice_pk)
        active_from = 10
        claim_txi = 100
        expire = 10_000
        bid_txi = Enum.random(100..1_000)

        bid_expire =
          :aec_governance.name_claim_bid_timeout(name, :aec_hard_forks.protocol_vsn(:lima) + 1)

        store =
          store
          |> Store.put(
            Model.InactiveName,
            Model.name(
              index: name,
              owner: alice_pk,
              active: active_from,
              expire: expire
            )
          )
          |> Store.put(
            Model.AuctionBid,
            Model.auction_bid(
              index: name,
              expire_height: bid_expire
            )
          )
          |> Store.put(
            Model.NameClaim,
            Model.name_claim(index: {name, active_from, {claim_txi, -1}})
          )
          |> Store.put(
            Model.AuctionBidClaim,
            Model.auction_bid_claim(index: {name, bid_expire, {bid_txi, -1}})
          )
          |> Store.put(Model.AuctionOwner, Model.owner(index: {alice_pk, name}))
          |> Store.put(Model.AuctionExpiration, Model.expiration(index: {bid_expire, name}))
          |> Store.put(
            Model.Tx,
            Model.tx(index: bid_txi, id: :aetx_sign.hash(tx), block_index: {1, 1})
          )
          |> Store.put(
            Model.Block,
            Model.block(index: {bid_expire, -1}, hash: mb_hash, tx_index: 2)
          )

        assert %{
                 "name" => ^name,
                 "active" => false,
                 "auction" => %{
                   "auction_end" => ^bid_expire,
                   "bids" => [^bid_txi],
                   "approximate_auction_end_time" => ^block_time
                 },
                 "info" => %{
                   "active_from" => ^active_from,
                   "auction_timeout" => 0,
                   "ownership" => %{"current" => ^owner_id, "original" => ^owner_id},
                   "pointers" => %{},
                   "revoke" => nil,
                   "transfers" => [],
                   "updates" => [],
                   "claims" => [^claim_txi],
                   "expire_height" => ^expire
                 },
                 "previous" => [],
                 "status" => "auction"
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/#{name}")
                 |> json_response(200)
      end
    end

    test "get name info by encoded hash ", %{conn: conn} do
      hash = "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj"
      hash_id = Validate.id!(hash)
      name = "some-name.chain"

      with_mocks [
        {Name, [],
         [
           plain_name: fn _state, ^hash_id -> {:ok, name} end,
           locate: fn _state, ^name ->
             {Model.name(index: name, active: true, expire: 0), Model.ActiveName}
           end,
           locate_bid: fn _state, ^name -> nil end,
           pointers: fn _state, _name_model -> %{} end,
           ownership: fn _state, _name -> %{original: <<>>, current: <<>>} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]}
      ] do
        assert %{"active" => true, "name" => ^name} =
                 conn |> get("/v2/names/#{hash}") |> json_response(200)
      end
    end

    test "renders error when no such name is present", %{conn: conn} do
      name = "no--such--name--in--the--chain.chain"
      error = "not found: #{name}"

      with_mocks [{Name, [], [locate: fn _state, ^name -> nil end]}] do
        assert %{"error" => ^error} = conn |> get("/v2/names/#{name}") |> json_response(404)
      end
    end
  end

  describe "pointers" do
    test "get pointers for valid given name", %{conn: conn, store: store} do
      name = "wwwbeaconoidcom.chain"
      {:ok, name_hash} = :aens.get_name_hash(name)
      active_height = 3

      with_blockchain %{alice: 1_000},
        mb: [
          tx1: name_tx(:name_claim_tx, :alice, name),
          tx2: name_tx(:name_update_tx, :alice, name)
        ] do
        tx2 = transactions[:tx2]

        store =
          store
          |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 2))
          |> Store.put(
            Model.Tx,
            Model.tx(index: 2, block_index: {0, 0}, id: :aetx_sign.hash(tx2))
          )
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: name))
          |> Store.put(Model.ActiveName, Model.name(index: name, active: active_height))
          |> Store.put(Model.NameUpdate, Model.name_update(index: {name, active_height, {2, -1}}))

        {:id, :account, alice_pk} = accounts[:alice]
        alice_id = encode(:account_pubkey, alice_pk)
        oracle_id = encode(:oracle_pubkey, alice_pk)

        assert %{
                 "account_pubkey" => ^alice_id,
                 "oracle_pubkey" => ^oracle_id
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/#{name}/pointers")
                 |> json_response(200)
      end
    end

    test "when last update tx is internal, it gets pointers for valid given name", %{
      conn: conn,
      store: store
    } do
      name = "wwwbeaconoidcom.chain"
      {:ok, name_hash} = :aens.get_name_hash(name)
      active_height = 3

      with_blockchain %{alice: 1_000},
        mb: [
          tx1: name_tx(:name_claim_tx, :alice, name),
          tx2: name_tx(:name_update_tx, :alice, name)
        ] do
        tx2 = transactions[:tx2]
        aetx2 = :aetx_sign.tx(tx2)

        store =
          store
          |> Store.put(Model.Block, Model.block(index: {0, 0}, tx_index: 2))
          |> Store.put(
            Model.Tx,
            Model.tx(index: 2, block_index: {0, 0}, id: :aetx_sign.hash(tx2))
          )
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: name))
          |> Store.put(Model.ActiveName, Model.name(index: name, active: active_height))
          |> Store.put(Model.IntContractCall, Model.int_contract_call(index: {2, 0}, tx: aetx2))
          |> Store.put(Model.NameUpdate, Model.name_update(index: {name, active_height, {2, 0}}))

        {:id, :account, alice_pk} = accounts[:alice]
        alice_id = encode(:account_pubkey, alice_pk)
        oracle_id = encode(:oracle_pubkey, alice_pk)

        assert %{
                 "account_pubkey" => ^alice_id,
                 "oracle_pubkey" => ^oracle_id
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/#{name}/pointers")
                 |> json_response(200)
      end
    end

    test "renders error when the name is missing", %{conn: conn} do
      id = "no--such--name--in--the--chain.chain"
      error = "not found: #{id}"

      with_mocks [{Name, [], [locate: fn _state, ^id -> nil end]}] do
        assert %{"error" => ^error} =
                 conn |> get("/v2/names/#{id}/pointers") |> json_response(404)
      end
    end
  end

  describe "pointees" do
    test "get pointees for valid public key", %{conn: conn} do
      id = "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
      name_id = Validate.name_id!(id)
      active_pointees = [%{"foo" => "active"}]
      inactive_pointees = [%{"foo" => "inactive"}]

      with_mocks [
        {Name, [], [pointees: fn _state, ^name_id -> {active_pointees, inactive_pointees} end]}
      ] do
        assert %{"active" => ^active_pointees, "inactive" => ^inactive_pointees} =
                 conn
                 |> get("/v2/names/#{id}/pointees")
                 |> json_response(200)
      end
    end

    test "renders error when the key is invalid", %{conn: conn} do
      id = "ak_invalidkey"
      error = "invalid id: #{id}"

      assert %{"error" => ^error} = conn |> get("/v2/names/#{id}/pointees") |> json_response(400)
    end
  end

  describe "owned_by" do
    test "get active names for given account/owner", %{conn: conn} do
      id = "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
      owner_pk = Validate.id!(id)
      plain_name = "ownername"

      store =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(
          Model.ActiveNameOwner,
          Model.owner(index: {owner_pk, plain_name})
        )
        |> Store.put(
          Model.ActiveName,
          Model.name(
            index: plain_name,
            active: 100,
            expire: 200,
            owner: owner_pk,
            auction_timeout: 0
          )
        )

      assert %{"active" => active_names, "top_bid" => []} =
               conn |> with_store(store) |> get("/names/owned_by/#{id}") |> json_response(200)

      assert %{
               "active" => true,
               "info" => %{
                 "active_from" => 100,
                 "expire_height" => 200,
                 "ownership" => %{"current" => ^id}
               },
               "name" => ^plain_name,
               "status" => "name"
             } = hd(active_names)
    end

    test "get inactive names for given account/owner", %{conn: conn} do
      id = "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
      owner_id = Validate.id!(id)

      with_mocks [
        {Name, [], [owned_by: fn _state, ^owner_id, false -> %{names: []} end]}
      ] do
        assert %{"inactive" => []} =
                 conn |> get("/names/owned_by/#{id}?active=false") |> json_response(200)
      end
    end

    test "renders error when the key is invalid", %{conn: conn} do
      id = "ak_invalid_key"
      error = "invalid id: #{id}"

      assert %{"error" => ^error} = conn |> get("/names/owned_by/#{id}") |> json_response(400)
    end
  end

  describe "name_claims" do
    test "it returns all of the name claims in backward order", %{conn: conn, store: store} do
      account_pk = TS.address(0)
      account_id = :aeser_id.create(:account, account_pk)
      plain_name = "asd.chain"

      store = name_claims_store(store, plain_name)
      conn = with_store(conn, store)
      tx1_hash_enc = Enc.encode(:tx_hash, <<0::256>>)
      tx2_hash_enc = Enc.encode(:tx_hash, <<1::256>>)
      tx3_hash_enc = Enc.encode(:tx_hash, <<2::256>>)

      {:ok, aetx1} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 111,
          name: plain_name,
          name_salt: 1_111,
          name_fee: 11_111,
          fee: 111_111,
          ttl: 1_111_111
        })

      {:name_claim_tx, tx1} = :aetx.specialize_type(aetx1)

      {:ok, aetx2} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 222,
          name: plain_name,
          name_salt: 2_222,
          name_fee: 22_222,
          fee: 222_222,
          ttl: 2_222_222
        })

      {:name_claim_tx, tx2} = :aetx.specialize_type(aetx2)

      {:ok, aetx3} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 333,
          name: plain_name,
          name_salt: 3_333,
          name_fee: 33_333,
          fee: 333_333,
          ttl: 3_333_333
        })

      {:name_claim_tx, tx3} = :aetx.specialize_type(aetx3)

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             <<0::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx1, []), tx1}

             <<1::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx2, []), tx2}

             <<2::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx3, []), tx3}
           end
         ]}
      ] do
        assert %{"data" => [claim3, claim2] = claims, "next" => next_url} =
                 conn
                 |> get("/v2/names/#{plain_name}/claims", limit: 2)
                 |> json_response(200)

        refute is_nil(next_url)

        assert %{
                 "height" => 124,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^tx3_hash_enc,
                 "internal_source" => false,
                 "tx" => %{"fee" => 333_333}
               } = claim3

        assert %{
                 "height" => 123,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^tx2_hash_enc,
                 "internal_source" => false,
                 "tx" => %{"fee" => 222_222}
               } = claim2

        assert %{"data" => [claim1], "prev" => prev_url} =
                 conn |> get(next_url) |> json_response(200)

        refute is_nil(prev_url)

        assert %{
                 "height" => 123,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^tx1_hash_enc,
                 "internal_source" => false,
                 "tx" => %{"fee" => 111_111}
               } = claim1

        assert %{"data" => ^claims} = conn |> get(prev_url) |> json_response(200)
      end
    end

    test "it returns all of the name claims in forward order", %{conn: conn, store: store} do
      account_pk = TS.address(0)
      account_id = :aeser_id.create(:account, account_pk)
      plain_name = "asd.chain"

      store = name_claims_store(store, plain_name)
      conn = with_store(conn, store)

      {:ok, aetx1} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 111,
          name: plain_name,
          name_salt: 1_111,
          name_fee: 11_111,
          fee: 111_111,
          ttl: 1_111_111
        })

      {:name_claim_tx, tx1} = :aetx.specialize_type(aetx1)

      {:ok, aetx2} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 222,
          name: plain_name,
          name_salt: 2_222,
          name_fee: 22_222,
          fee: 222_222,
          ttl: 2_222_222
        })

      {:name_claim_tx, tx2} = :aetx.specialize_type(aetx2)

      {:ok, aetx3} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 333,
          name: plain_name,
          name_salt: 3_333,
          name_fee: 33_333,
          fee: 333_333,
          ttl: 3_333_333
        })

      {:name_claim_tx, tx3} = :aetx.specialize_type(aetx3)

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             <<0::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx1, []), tx1}

             <<1::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx2, []), tx2}

             <<2::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx3, []), tx3}
           end
         ]}
      ] do
        assert %{"data" => [claim1, claim2] = claims, "next" => next_url} =
                 conn
                 |> get("/v2/names/#{plain_name}/claims", limit: 2, direction: "forward")
                 |> json_response(200)

        refute is_nil(next_url)
        assert %{"height" => 123, "tx" => %{"fee" => 111_111}} = claim1
        assert %{"height" => 123, "tx" => %{"fee" => 222_222}} = claim2

        assert %{"data" => [claim3], "prev" => prev_url} =
                 conn |> get(next_url) |> json_response(200)

        refute is_nil(prev_url)
        assert %{"height" => 124, "tx" => %{"fee" => 333_333}} = claim3

        assert %{"data" => ^claims} = conn |> get(prev_url) |> json_response(200)
      end
    end

    test "it returns all of the auction claims in forward order", %{conn: conn, store: store} do
      account_pk = TS.address(0)
      account_id = :aeser_id.create(:account, account_pk)
      plain_name = "asd.chain"
      expire_height = 1000
      claim_txi_idx1 = {567, -1}
      claim_txi_idx2 = {678, -1}
      claim_txi_idx3 = {788, -1}

      auction_bid =
        Model.auction_bid(
          index: plain_name,
          expire_height: expire_height
        )

      store =
        store
        |> Store.put(Model.AuctionBid, auction_bid)
        |> Store.put(Model.Tx, Model.tx(index: 567, block_index: {123, 0}, id: <<0::256>>))
        |> Store.put(Model.Tx, Model.tx(index: 678, block_index: {123, 0}, id: <<1::256>>))
        |> Store.put(Model.Tx, Model.tx(index: 788, block_index: {124, 1}, id: <<2::256>>))
        |> Store.put(Model.Block, Model.block(index: {123, 0}, hash: "mb1-hash"))
        |> Store.put(Model.Block, Model.block(index: {124, 1}, hash: "mb2-hash"))
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, expire_height, claim_txi_idx1})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, expire_height, claim_txi_idx2})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, expire_height, claim_txi_idx3})
        )

      conn = with_store(conn, store)

      {:ok, aetx1} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 111,
          name: plain_name,
          name_salt: 1_111,
          name_fee: 11_111,
          fee: 111_111,
          ttl: 1_111_111
        })

      {:name_claim_tx, tx1} = :aetx.specialize_type(aetx1)

      {:ok, aetx2} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 222,
          name: plain_name,
          name_salt: 2_222,
          name_fee: 22_222,
          fee: 222_222,
          ttl: 2_222_222
        })

      {:name_claim_tx, tx2} = :aetx.specialize_type(aetx2)

      {:ok, aetx3} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 333,
          name: plain_name,
          name_salt: 3_333,
          name_fee: 33_333,
          fee: 333_333,
          ttl: 3_333_333
        })

      {:name_claim_tx, tx3} = :aetx.specialize_type(aetx3)

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             <<0::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx1, []), tx1}

             <<1::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx2, []), tx2}

             <<2::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx3, []), tx3}
           end
         ]}
      ] do
        assert %{"data" => [claim1, claim2] = claims, "next" => next_url} =
                 conn
                 |> get("/v2/names/#{plain_name}/claims", limit: 2, direction: "forward")
                 |> json_response(200)

        refute is_nil(next_url)
        assert %{"height" => 123, "tx" => %{"fee" => 111_111}} = claim1
        assert %{"height" => 123, "tx" => %{"fee" => 222_222}} = claim2

        assert %{"data" => [claim3], "prev" => prev_url} =
                 conn |> get(next_url) |> json_response(200)

        refute is_nil(prev_url)
        assert %{"height" => 124, "tx" => %{"fee" => 333_333}} = claim3

        assert %{"data" => ^claims} = conn |> get(prev_url) |> json_response(200)
      end
    end

    test "it returns 404 when name doesn't exist", %{conn: conn, store: store} do
      non_existent_name = "asd.chain"
      error_msg = "not found: #{non_existent_name}"

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v2/names/#{non_existent_name}/claims")
               |> json_response(404)
    end

    test "it returns internal AENS.claim calls", %{conn: conn, store: store} do
      account_pk = TS.address(0)
      account_id = :aeser_id.create(:account, account_pk)
      contract_pk = TS.address(1)
      contract_id = :aeser_id.create(:contract, contract_pk)
      plain_name = "asd.chain"
      plain_name2 = "asd2.chain"
      call_txi = 567
      tx1_hash_enc = Enc.encode(:tx_hash, <<0::256>>)

      {:ok, contract_call_aetx} =
        :aect_call_tx.new(%{
          caller_id: account_id,
          nonce: 111,
          contract_id: contract_id,
          abi_version: 0,
          fee: 1_111,
          amount: 11_111,
          gas: 111_111,
          gas_price: 1_111_111,
          call_data: ""
        })

      {:contract_call_tx, contract_call_tx} = :aetx.specialize_type(contract_call_aetx)

      {:ok, aetx1} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 111,
          name: plain_name2,
          name_salt: 1_111,
          name_fee: 11_111,
          fee: 111_111,
          ttl: 1_111_111
        })

      int_contract_call =
        Model.int_contract_call(index: {call_txi, 1}, fname: "AENS.claim", tx: aetx1)

      store =
        store
        |> name_claims_store(plain_name)
        |> Store.put(Model.IntContractCall, int_contract_call)

      {:ok, Model.name(active: active) = name} = Store.get(store, Model.ActiveName, plain_name)

      store =
        store
        |> Store.put(Model.ActiveName, Model.name(name, index: plain_name2))
        |> Store.put(
          Model.NameClaim,
          Model.name_claim(index: {plain_name2, active, {call_txi, 1}})
        )

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             <<0::256>> ->
               {"", :contract_call_tx, :aetx_sign.new(contract_call_aetx, []), contract_call_tx}
           end
         ]}
      ] do
        assert %{"data" => [claim1]} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/#{plain_name2}/claims", limit: 1, direction: "forward")
                 |> json_response(200)

        assert %{
                 "height" => 123,
                 "source_tx_hash" => ^tx1_hash_enc,
                 "source_tx_type" => "ContractCallTx",
                 "internal_source" => true,
                 "tx" => %{"fee" => 111_111, "name" => ^plain_name2}
               } = claim1
      end
    end
  end

  describe "name_transfers" do
    test "it returns all of the name transfers in backward order", %{conn: conn, store: store} do
      account_pk = TS.address(0)
      account_id = :aeser_id.create(:account, account_pk)
      recipient_pk = TS.address(1)
      recipient_id = :aeser_id.create(:account, recipient_pk)
      plain_name = "asd.chain"
      {:ok, name_hash} = :aens.get_name_hash(plain_name)
      name_id = :aeser_id.create(:name, name_hash)

      store = name_claims_store(store, plain_name)
      conn = with_store(conn, store)

      {:ok, aetx1} =
        :aens_transfer_tx.new(%{
          account_id: account_id,
          nonce: 111,
          name_id: name_id,
          recipient_id: recipient_id,
          fee: 1_111,
          ttl: 11_111
        })

      {:name_transfer_tx, tx1} = :aetx.specialize_type(aetx1)

      {:ok, aetx2} =
        :aens_transfer_tx.new(%{
          account_id: account_id,
          nonce: 222,
          name_id: name_id,
          recipient_id: recipient_id,
          fee: 222_222,
          ttl: 2_222_222
        })

      {:name_transfer_tx, tx2} = :aetx.specialize_type(aetx2)

      {:ok, aetx3} =
        :aens_transfer_tx.new(%{
          account_id: account_id,
          nonce: 333,
          name_id: name_id,
          recipient_id: recipient_id,
          fee: 333_333,
          ttl: 3_333_333
        })

      {:name_transfer_tx, tx3} = :aetx.specialize_type(aetx3)

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             <<0::256>> ->
               {"", :name_transfer_tx, :aetx_sign.new(aetx1, []), tx1}

             <<1::256>> ->
               {"", :name_transfer_tx, :aetx_sign.new(aetx2, []), tx2}

             <<2::256>> ->
               {"", :name_transfer_tx, :aetx_sign.new(aetx3, []), tx3}
           end
         ]}
      ] do
        assert %{"data" => [claim3, claim2] = claims, "next" => next_url} =
                 conn
                 |> get("/v2/names/#{plain_name}/transfers", limit: 2)
                 |> json_response(200)

        refute is_nil(next_url)
        assert %{"height" => 124, "tx" => %{"fee" => 333_333}} = claim3
        assert %{"height" => 123, "tx" => %{"fee" => 222_222}} = claim2

        assert %{"data" => [claim1], "prev" => prev_url} =
                 conn |> get(next_url) |> json_response(200)

        refute is_nil(prev_url)
        assert %{"height" => 123, "tx" => %{"fee" => 1_111}} = claim1

        assert %{"data" => ^claims} = conn |> get(prev_url) |> json_response(200)
      end
    end

    test "it returns 404 when name doesn't exist", %{conn: conn, store: store} do
      non_existent_name = "asd.chain"
      error_msg = "not found: #{non_existent_name}"

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v2/names/#{non_existent_name}/transfers")
               |> json_response(404)
    end
  end

  describe "name_updates" do
    test "it returns all of the name updates in backward order", %{conn: conn, store: store} do
      account_pk = TS.address(0)
      account_id = :aeser_id.create(:account, account_pk)
      plain_name = "asd.chain"
      {:ok, name_hash} = :aens.get_name_hash(plain_name)
      name_id = :aeser_id.create(:name, name_hash)

      store = name_claims_store(store, plain_name)
      conn = with_store(conn, store)

      {:ok, aetx1} =
        :aens_update_tx.new(%{
          account_id: account_id,
          nonce: 111,
          name_id: name_id,
          name_ttl: 1_111,
          pointers: [],
          client_ttl: 11_111,
          fee: 111_111
        })

      {:name_update_tx, tx1} = :aetx.specialize_type(aetx1)

      {:ok, aetx2} =
        :aens_update_tx.new(%{
          account_id: account_id,
          nonce: 222,
          name_id: name_id,
          name_ttl: 2_222,
          pointers: [],
          client_ttl: 22_222,
          fee: 222_222
        })

      {:name_update_tx, tx2} = :aetx.specialize_type(aetx2)

      {:ok, aetx3} =
        :aens_update_tx.new(%{
          account_id: account_id,
          nonce: 333,
          name_id: name_id,
          name_ttl: 3_333,
          pointers: [],
          client_ttl: 33_333,
          fee: 333_333
        })

      {:name_update_tx, tx3} = :aetx.specialize_type(aetx3)

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             <<0::256>> ->
               {"", :name_update_tx, :aetx_sign.new(aetx1, []), tx1}

             <<1::256>> ->
               {"", :name_update_tx, :aetx_sign.new(aetx2, []), tx2}

             <<2::256>> ->
               {"", :name_update_tx, :aetx_sign.new(aetx3, []), tx3}
           end
         ]}
      ] do
        assert %{"data" => [claim3, claim2] = claims, "next" => next_url} =
                 conn
                 |> get("/v2/names/#{plain_name}/updates", limit: 2)
                 |> json_response(200)

        refute is_nil(next_url)
        assert %{"height" => 124, "tx" => %{"fee" => 333_333}} = claim3
        assert %{"height" => 123, "tx" => %{"fee" => 222_222}} = claim2

        assert %{"data" => [claim1], "prev" => prev_url} =
                 conn |> get(next_url) |> json_response(200)

        refute is_nil(prev_url)
        assert %{"height" => 123, "tx" => %{"fee" => 111_111}} = claim1

        assert %{"data" => ^claims} = conn |> get(prev_url) |> json_response(200)
      end
    end

    test "it returns 404 when name doesn't exist", %{conn: conn, store: store} do
      non_existent_name = "asd.chain"
      error_msg = "not found: #{non_existent_name}"

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v2/names/#{non_existent_name}/updates")
               |> json_response(404)
    end
  end

  describe "name_history" do
    test "returns all the name operations in backward order", %{conn: conn, store: store} do
      account_pk = TS.address(0)
      account_id = :aeser_id.create(:account, account_pk)
      recipient_pk = TS.address(1)
      recipient_id = :aeser_id.create(:account, recipient_pk)
      plain_name = new_name()
      {:ok, name_hash} = :aens.get_name_hash(plain_name)
      name_id = :aeser_id.create(:name, name_hash)

      active_from1 = 5
      kbi1 = 7
      active_from2 = 8
      kbi2 = 8
      expired_at = 7 + 10

      store =
        name_history_store(store, active_from1, active_from2, kbi1, kbi2, expired_at, plain_name)

      conn = with_store(conn, store)

      {:ok, claim_aetx1} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 11,
          name: plain_name,
          name_salt: 1_111,
          name_fee: 11_111,
          fee: 111_111,
          ttl: 1_111_111
        })

      {:ok, update_aetx1} =
        :aens_update_tx.new(%{
          account_id: account_id,
          nonce: 12,
          name_id: name_id,
          name_ttl: 1_111,
          pointers: [],
          client_ttl: 11_111,
          fee: 111_111
        })

      {:ok, transfer_aetx} =
        :aens_transfer_tx.new(%{
          account_id: account_id,
          nonce: 13,
          name_id: name_id,
          recipient_id: recipient_id,
          fee: 1_111,
          ttl: 11_111
        })

      {:ok, revoke_aetx} =
        :aens_revoke_tx.new(%{
          account_id: account_id,
          nonce: 14,
          name_id: name_id,
          fee: 1_111
        })

      {:ok, claim_aetx2} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 21,
          name: plain_name,
          name_salt: 2_222,
          name_fee: 22_222,
          fee: 222_222,
          ttl: 2_222_222
        })

      {:ok, update_aetx2} =
        :aens_update_tx.new(%{
          account_id: account_id,
          nonce: 22,
          name_id: name_id,
          name_ttl: 2_222,
          pointers: [],
          client_ttl: 22_222,
          fee: 222_222
        })

      with_mocks [
        {Db, [:passthrough],
         [
           get_tx_data: fn
             <<501::256>> ->
               {:name_claim_tx, tx} = :aetx.specialize_type(claim_aetx1)
               {"", :name_claim_tx, :aetx_sign.new(claim_aetx1, []), tx}

             <<502::256>> ->
               {:name_update_tx, tx} = :aetx.specialize_type(update_aetx1)
               {"", :name_update_tx, :aetx_sign.new(update_aetx1, []), tx}

             <<503::256>> ->
               {:name_transfer_tx, tx} = :aetx.specialize_type(transfer_aetx)
               {"", :name_transfer_tx, :aetx_sign.new(transfer_aetx, []), tx}

             <<504::256>> ->
               {:name_revoke_tx, tx} = :aetx.specialize_type(revoke_aetx)
               {"", :name_revoke_tx, :aetx_sign.new(revoke_aetx, []), tx}

             <<601::256>> ->
               {:name_claim_tx, tx} = :aetx.specialize_type(claim_aetx2)
               {"", :name_claim_tx, :aetx_sign.new(claim_aetx2, []), tx}

             <<602::256>> ->
               {:name_update_tx, tx} = :aetx.specialize_type(update_aetx2)
               {"", :name_update_tx, :aetx_sign.new(update_aetx2, []), tx}
           end
         ]}
      ] do
        [claim1_hash, update1_hash, transfer_hash, revoke_hash] =
          for i <- 1..4, do: Enc.encode(:tx_hash, <<500 + i::256>>)

        [claim2_hash, update2_hash] = for i <- 1..2, do: Enc.encode(:tx_hash, <<600 + i::256>>)

        plain_name = String.replace(plain_name, ".chain", "")

        assert %{
                 "data" => [expired, update2, claim2, revoke, transfer] = history,
                 "next" => next_url
               } =
                 conn
                 |> get("/v2/names/#{plain_name}/history", limit: 5)
                 |> json_response(200)

        assert %{
                 "data" => ^history,
                 "next" => next_url_hash
               } =
                 conn
                 |> get("/v2/names/#{encode(:name, name_hash)}/history", limit: 5)
                 |> json_response(200)

        assert URI.parse(next_url).query == URI.parse(next_url_hash).query

        refute is_nil(next_url)

        assert %{
                 "active_from" => ^kbi2,
                 "expired_at" => ^expired_at
               } = expired

        assert %{
                 "active_from" => ^active_from2,
                 "height" => ^kbi2,
                 "source_tx_type" => "NameUpdateTx",
                 "source_tx_hash" => ^update2_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 22}
               } = update2

        assert %{
                 "active_from" => ^active_from2,
                 "height" => ^kbi2,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^claim2_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 21}
               } = claim2

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameRevokeTx",
                 "source_tx_hash" => ^revoke_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 14}
               } = revoke

        recipient = encode_account(recipient_pk)

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameTransferTx",
                 "source_tx_hash" => ^transfer_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 13, "recipient_id" => ^recipient}
               } = transfer

        assert %{"data" => [update1, claim1], "prev" => prev_url} =
                 conn |> get(next_url) |> json_response(200)

        refute is_nil(prev_url)

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameUpdateTx",
                 "source_tx_hash" => ^update1_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 12}
               } = update1

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^claim1_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 11}
               } = claim1

        assert %{"data" => ^history} = conn |> get(prev_url) |> json_response(200)
      end
    end

    test "returns all the name operations in forward order", %{conn: conn, store: store} do
      account_pk = TS.address(0)
      account_id = :aeser_id.create(:account, account_pk)
      recipient_pk = TS.address(1)
      recipient_id = :aeser_id.create(:account, recipient_pk)
      plain_name = new_name()
      {:ok, name_hash} = :aens.get_name_hash(plain_name)
      name_id = :aeser_id.create(:name, name_hash)
      active_from1 = 5
      kbi1 = 7
      active_from2 = 8
      kbi2 = 8
      expired_at = 7 + 10

      store =
        name_history_store(store, active_from1, active_from2, kbi1, kbi2, expired_at, plain_name)

      conn = with_store(conn, store)

      {:ok, claim_aetx1} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 11,
          name: plain_name,
          name_salt: 1_111,
          name_fee: 11_111,
          fee: 111_111,
          ttl: 1_111_111
        })

      {:ok, update_aetx1} =
        :aens_update_tx.new(%{
          account_id: account_id,
          nonce: 12,
          name_id: name_id,
          name_ttl: 1_111,
          pointers: [],
          client_ttl: 11_111,
          fee: 111_111
        })

      {:ok, transfer_aetx} =
        :aens_transfer_tx.new(%{
          account_id: account_id,
          nonce: 13,
          name_id: name_id,
          recipient_id: recipient_id,
          fee: 1_111,
          ttl: 11_111
        })

      {:ok, revoke_aetx} =
        :aens_revoke_tx.new(%{
          account_id: account_id,
          nonce: 14,
          name_id: name_id,
          fee: 1_111
        })

      {:ok, claim_aetx2} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 21,
          name: plain_name,
          name_salt: 2_222,
          name_fee: 22_222,
          fee: 222_222,
          ttl: 2_222_222
        })

      {:ok, update_aetx2} =
        :aens_update_tx.new(%{
          account_id: account_id,
          nonce: 22,
          name_id: name_id,
          name_ttl: 2_222,
          pointers: [],
          client_ttl: 22_222,
          fee: 222_222
        })

      with_mocks [
        {Db, [:passthrough],
         [
           get_tx_data: fn
             <<501::256>> ->
               {:name_claim_tx, tx} = :aetx.specialize_type(claim_aetx1)
               {"", :name_claim_tx, :aetx_sign.new(claim_aetx1, []), tx}

             <<502::256>> ->
               {:name_update_tx, tx} = :aetx.specialize_type(update_aetx1)
               {"", :name_update_tx, :aetx_sign.new(update_aetx1, []), tx}

             <<503::256>> ->
               {:name_transfer_tx, tx} = :aetx.specialize_type(transfer_aetx)
               {"", :name_transfer_tx, :aetx_sign.new(transfer_aetx, []), tx}

             <<504::256>> ->
               {:name_revoke_tx, tx} = :aetx.specialize_type(revoke_aetx)
               {"", :name_revoke_tx, :aetx_sign.new(revoke_aetx, []), tx}

             <<601::256>> ->
               {:name_claim_tx, tx} = :aetx.specialize_type(claim_aetx2)
               {"", :name_claim_tx, :aetx_sign.new(claim_aetx2, []), tx}

             <<602::256>> ->
               {:name_update_tx, tx} = :aetx.specialize_type(update_aetx2)
               {"", :name_update_tx, :aetx_sign.new(update_aetx2, []), tx}
           end
         ]}
      ] do
        [claim1_hash, update1_hash, transfer_hash, revoke_hash] =
          for i <- 1..4, do: Enc.encode(:tx_hash, <<500 + i::256>>)

        [claim2_hash, update2_hash] = for i <- 1..2, do: Enc.encode(:tx_hash, <<600 + i::256>>)

        assert %{
                 "data" => [claim1, update1, transfer, revoke] = history,
                 "next" => next_url
               } =
                 conn
                 |> get("/v2/names/#{plain_name}/history", direction: "forward", limit: 4)
                 |> json_response(200)

        refute is_nil(next_url)

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^claim1_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 11}
               } = claim1

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameUpdateTx",
                 "source_tx_hash" => ^update1_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 12}
               } = update1

        recipient = encode_account(recipient_pk)

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameTransferTx",
                 "source_tx_hash" => ^transfer_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 13, "recipient_id" => ^recipient}
               } = transfer

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameRevokeTx",
                 "source_tx_hash" => ^revoke_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 14}
               } = revoke

        assert %{"data" => [claim2, update2, expired], "prev" => prev_url} =
                 conn |> get(next_url) |> json_response(200)

        refute is_nil(prev_url)

        assert %{
                 "active_from" => ^active_from2,
                 "height" => ^kbi2,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^claim2_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 21}
               } = claim2

        assert %{
                 "active_from" => ^active_from2,
                 "height" => ^kbi2,
                 "source_tx_type" => "NameUpdateTx",
                 "source_tx_hash" => ^update2_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 22}
               } = update2

        assert %{
                 "active_from" => ^kbi2,
                 "expired_at" => ^expired_at
               } = expired

        assert %{"data" => ^history} = conn |> get(prev_url) |> json_response(200)
      end
    end

    test "it returns 404 when name doesn't exist", %{conn: conn, store: store} do
      non_existent_name = "asd.chain"
      error_msg = "not found: #{non_existent_name}"

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v2/names/#{non_existent_name}/updates")
               |> json_response(404)
    end
  end

  describe "bids" do
    test "it returns all of the auction claims in forward order", %{conn: conn, store: store} do
      account_pk = TS.address(0)
      account_id = :aeser_id.create(:account, account_pk)
      plain_name = "asd.chain"
      expire_height = 1000
      claim_txi_idx1 = {567, -1}
      claim_txi_idx2 = {678, -1}
      claim_txi_idx3 = {788, -1}

      auction_bid =
        Model.auction_bid(
          index: plain_name,
          expire_height: expire_height
        )

      store =
        store
        |> Store.put(Model.AuctionBid, auction_bid)
        |> Store.put(Model.Tx, Model.tx(index: 567, block_index: {123, 0}, id: <<0::256>>))
        |> Store.put(Model.Tx, Model.tx(index: 678, block_index: {123, 0}, id: <<1::256>>))
        |> Store.put(Model.Tx, Model.tx(index: 788, block_index: {124, 1}, id: <<2::256>>))
        |> Store.put(Model.Block, Model.block(index: {123, 0}, hash: <<0::256>>))
        |> Store.put(Model.Block, Model.block(index: {124, 1}, hash: <<1::256>>))
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, expire_height, claim_txi_idx1})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, expire_height, claim_txi_idx2})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, expire_height, claim_txi_idx3})
        )

      conn = with_store(conn, store)

      {:ok, aetx1} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 111,
          name: plain_name,
          name_salt: 1_111,
          name_fee: 11_111,
          fee: 111_111,
          ttl: 1_111_111
        })

      {:name_claim_tx, tx1} = :aetx.specialize_type(aetx1)

      {:ok, aetx2} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 222,
          name: plain_name,
          name_salt: 2_222,
          name_fee: 22_222,
          fee: 222_222,
          ttl: 2_222_222
        })

      {:name_claim_tx, tx2} = :aetx.specialize_type(aetx2)

      {:ok, aetx3} =
        :aens_claim_tx.new(%{
          account_id: account_id,
          nonce: 333,
          name: plain_name,
          name_salt: 3_333,
          name_fee: 33_333,
          fee: 333_333,
          ttl: 3_333_333
        })

      {:name_claim_tx, tx3} = :aetx.specialize_type(aetx3)

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             <<0::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx1, []), tx1}

             <<1::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx2, []), tx2}

             <<2::256>> ->
               {"", :name_claim_tx, :aetx_sign.new(aetx3, []), tx3}
           end
         ]}
      ] do
        assert %{"data" => [claim1, claim2] = claims, "next" => next_url} =
                 conn
                 |> get("/v3/names/auctions/#{plain_name}/claims", limit: 2, direction: "forward")
                 |> json_response(200)

        refute is_nil(next_url)
        assert %{"height" => 123, "tx" => %{"fee" => 111_111}} = claim1
        assert %{"height" => 123, "tx" => %{"fee" => 222_222}} = claim2

        assert %{"data" => [claim3], "prev" => prev_url} =
                 conn |> get(next_url) |> json_response(200)

        refute is_nil(prev_url)
        assert %{"height" => 124, "tx" => %{"fee" => 333_333}} = claim3

        assert %{"data" => ^claims} = conn |> get(prev_url) |> json_response(200)
      end
    end
  end

  describe "search_v1" do
    test "it returns error when invalid lifecycle", %{conn: conn} do
      error_msg = "invalid query: name lifecycle foo"

      %{"error" => ^error_msg} =
        conn
        |> get("/names/search/foo", only: "foo")
        |> json_response(400)
    end

    test "it returns error when invalid filter", %{conn: conn} do
      error_msg = "invalid query: foo=bar"

      %{"error" => ^error_msg} =
        conn
        |> get("/names/search/foo", foo: "bar")
        |> json_response(400)
    end
  end

  defp name_history_store(store, active_from1, active_from2, kbi1, kbi2, expired_at, plain_name) do
    claim1 = {501, -1}
    update1 = {502, -1}
    transfer = {503, -1}
    revoke = {504, -1}
    claim2 = {601, -1}
    update2 = {602, -1}
    {:ok, name_hash} = :aens.get_name_hash(plain_name)

    m_name =
      Model.name(
        index: plain_name,
        active: active_from2,
        expire: expired_at,
        revoke: nil,
        auction_timeout: 1
      )

    store
    |> Store.put(Model.ActiveName, m_name)
    |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
    |> Store.put(Model.NameClaim, Model.name_claim(index: {plain_name, active_from1, claim1}))
    |> Store.put(Model.NameUpdate, Model.name_update(index: {plain_name, active_from1, update1}))
    |> Store.put(
      Model.NameTransfer,
      Model.name_transfer(index: {plain_name, active_from1, transfer})
    )
    |> Store.put(
      Model.NameRevoke,
      Model.name_transfer(index: {plain_name, active_from1, revoke})
    )
    |> Store.put(Model.NameClaim, Model.name_claim(index: {plain_name, active_from2, claim2}))
    |> Store.put(Model.NameUpdate, Model.name_update(index: {plain_name, active_from2, update2}))
    |> Store.put(
      Model.NameExpired,
      Model.name_expired(index: {plain_name, active_from2, {nil, expired_at}})
    )
    |> then(fn store ->
      Enum.reduce(0..3, store, fn i, store ->
        Store.put(
          store,
          Model.Tx,
          Model.tx(index: 501 + i, block_index: {kbi1, i}, id: <<501 + i::256>>)
        )
      end)
    end)
    |> then(fn store ->
      Enum.reduce(0..2, store, fn i, store ->
        Store.put(
          store,
          Model.Tx,
          Model.tx(index: 601 + i, block_index: {kbi2, i}, id: <<601 + i::256>>)
        )
      end)
    end)
    |> Store.put(Model.Block, Model.block(index: {kbi1, 0}, hash: "mb#{kbi1}-hash"))
    |> Store.put(Model.Block, Model.block(index: {kbi2, 0}, hash: "mb#{kbi2}-hash"))
  end

  defp name_claims_store(store, plain_name) do
    claim_txi_idx1 = {567, -1}
    claim_txi_idx2 = {678, -1}
    claim_txi_idx3 = {788, -1}
    active_height = 3

    name =
      Model.name(
        index: plain_name,
        active: active_height,
        expire: 3,
        revoke: nil,
        auction_timeout: 1
      )

    store
    |> Store.put(Model.ActiveName, name)
    |> Store.put(Model.Tx, Model.tx(index: 567, block_index: {123, 0}, id: <<0::256>>))
    |> Store.put(Model.Tx, Model.tx(index: 678, block_index: {123, 0}, id: <<1::256>>))
    |> Store.put(Model.Tx, Model.tx(index: 788, block_index: {124, 1}, id: <<2::256>>))
    |> Store.put(Model.Block, Model.block(index: {123, 0}, hash: "mb1-hash"))
    |> Store.put(Model.Block, Model.block(index: {124, 1}, hash: "mb2-hash"))
    |> Store.put(
      Model.NameClaim,
      Model.name_claim(index: {plain_name, active_height, claim_txi_idx1})
    )
    |> Store.put(
      Model.NameClaim,
      Model.name_claim(index: {plain_name, active_height, claim_txi_idx2})
    )
    |> Store.put(
      Model.NameClaim,
      Model.name_claim(index: {plain_name, active_height, claim_txi_idx3})
    )
    |> Store.put(
      Model.NameTransfer,
      Model.name_transfer(index: {plain_name, active_height, claim_txi_idx1})
    )
    |> Store.put(
      Model.NameTransfer,
      Model.name_transfer(index: {plain_name, active_height, claim_txi_idx2})
    )
    |> Store.put(
      Model.NameTransfer,
      Model.name_transfer(index: {plain_name, active_height, claim_txi_idx3})
    )
    |> Store.put(
      Model.NameUpdate,
      Model.name_update(index: {plain_name, active_height, claim_txi_idx1})
    )
    |> Store.put(
      Model.NameUpdate,
      Model.name_update(index: {plain_name, active_height, claim_txi_idx2})
    )
    |> Store.put(
      Model.NameUpdate,
      Model.name_update(index: {plain_name, active_height, claim_txi_idx3})
    )
  end
end
