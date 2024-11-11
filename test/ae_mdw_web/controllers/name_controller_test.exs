defmodule AeMdwWeb.NameControllerTest do
  alias AeMdw.Db.NullStore
  use AeMdwWeb.ConnCase, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Store
  alias AeMdw.Db.MemStore
  alias AeMdw.Node.Db
  alias AeMdw.TestSamples, as: TS
  alias AeMdw.Txs
  alias AeMdw.Validate

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
        [tx1: tx1, tx2: tx2, tx3: tx3, tx4: tx4] = transactions
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
                 |> get("/v3/names", state: "active", limit: 1)
                 |> json_response(200)

        assert %{
                 "name" => ^bob_name,
                 "active" => true,
                 "auction" => nil,
                 "active_from" => ^active_from,
                 "auction_timeout" => 0,
                 "ownership" => %{"current" => ^bob_id, "original" => ^bob_id},
                 "revoke" => nil,
                 "expire_height" => ^expire2,
                 "approximate_expire_time" => ^approx_expire_time1,
                 "pointers" => [
                   %{"key" => "account_pubkey", "id" => ^bob_id},
                   %{"key" => "oracle_pubkey", "id" => ^bob_oracle_id}
                 ]
               } = name1

        assert %{"data" => [name2]} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        assert %{
                 "name" => ^alice_name,
                 "active" => true,
                 "auction" => nil,
                 "active_from" => ^active_from,
                 "auction_timeout" => 0,
                 "ownership" => %{"current" => ^alice_id, "original" => ^alice_id},
                 "pointers" => [
                   %{
                     "key" => "account_pubkey",
                     "id" => ^alice_id
                   },
                   %{"key" => "oracle_pubkey", "id" => ^alice_oracle_id}
                 ],
                 "revoke" => nil,
                 "expire_height" => ^expire1,
                 "approximate_expire_time" => ^approx_expire_time2
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
          txi = expire - 10

          name =
            Model.name(
              index: plain_name,
              active: txi,
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
          |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>))
          |> Store.put(Model.Block, Model.block(index: {height, -1}, hash: key_hash))
          |> Store.put(Model.Block, Model.block(index: {txi, -1}, hash: key_hash))
        end)
        |> Store.put(Model.ActiveNameExpiration, Model.expiration(index: {121, height_name[121]}))

      with_mocks [
        {Txs, [:passthrough],
         [
           fetch!: fn _state, _hash, _opts -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers_v3: fn _state, _mname -> [] end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [:passthrough], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names", state: "active")
                 |> json_response(200)

        assert @default_limit = length(names)

        assert names ==
                 Enum.sort_by(
                   names,
                   fn %{"expire_height" => expire} -> expire end,
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
                   fn %{"expire_height" => expire} -> expire end,
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
              active: 1,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.ActiveName, name)
          |> Store.put(Model.Tx, Model.tx(index: i - 1, id: <<i::256>>))
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))
        |> Store.put(Model.Block, Model.block(index: {2, -1}, hash: key_hash))

      with_mocks [
        {Txs, [:passthrough],
         [
           fetch!: fn _state, _hash, _opts -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers_v3: fn _state, _mname -> [] end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [:passthrough], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names", state: "active", by: by, direction: direction, limit: limit)
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
               conn |> get("/v3/names", state: "active", by: by) |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid direction: #{direction}"

      assert %{"error" => ^error} =
               conn
               |> get("/v3/names", state: "active", by: by, direction: direction)
               |> json_response(400)
    end

    test "it renders active names with ga_meta transactions", %{conn: conn, store: store} do
      key_hash = <<0::256>>
      plain_name = "a.chain"

      name =
        Model.name(
          index: plain_name,
          active: 1,
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
        |> Store.put(Model.PreviousName, Model.previous_name(index: {plain_name, 0}, name: name))
        |> Store.put(Model.Tx, Model.tx(index: 0, id: <<1::256>>, block_index: {1, 0}))

      with_mocks [
        {Txs, [:passthrough],
         [
           fetch!: fn _state, _hash, _opts ->
             %{"tx" => %{"tx" => %{"tx" => %{"pointers" => [], "account_id" => <<>>}}}}
           end
         ]},
        {Name, [],
         [
           pointers_v3: fn _state, _mname -> [] end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [:passthrough], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names", state: "active")
                 |> json_response(200)

        assert 1 = length(names)
        assert [%{"name" => ^plain_name, "pointers" => []}] = names
      end
    end
  end

  describe "inactive_names" do
    test "renders inactive names with detailed info", %{conn: conn, store: store} do
      alice_name = "aliceinchains.chain"
      bob_name = "bobandmarley.chain"
      {:ok, alice_hash} = :aens.get_name_hash(alice_name)
      {:ok, bob_hash} = :aens.get_name_hash(bob_name)

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
        [tx1: tx1, tx2: tx2, tx3: tx3, tx4: tx4, tx5: tx5] = transactions
        alice_revoke_hash = tx2 |> :aetx_sign.hash() |> then(&encode(:tx_hash, &1))
        bob_revoke_hash = tx5 |> :aetx_sign.hash() |> then(&encode(:tx_hash, &1))
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
          |> Store.put(Model.PlainName, Model.plain_name(index: alice_hash, value: alice_name))
          |> Store.put(Model.PlainName, Model.plain_name(index: bob_hash, value: bob_name))

        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names", state: "inactive")
                 |> json_response(200)

        bob_encoded_account_id = encode(:account_pubkey, bob_pk)

        assert [
                 %{
                   "name" => ^bob_name,
                   "active" => false,
                   "auction" => nil,
                   "active_from" => ^active_from,
                   "auction_timeout" => 0,
                   "ownership" => %{"current" => ^bob_id, "original" => ^bob_id},
                   "expire_height" => ^expire2,
                   "revoke" => %{"tx_hash" => ^bob_revoke_hash},
                   "approximate_expire_time" => ^approx_expire_time2,
                   "pointers" => [
                     %{
                       "key" => "account_pubkey",
                       "id" => ^bob_encoded_account_id
                     },
                     %{"key" => "oracle_pubkey", "id" => ^bob_oracle_id}
                   ]
                 },
                 %{
                   "name" => ^alice_name,
                   "active" => false,
                   "auction" => nil,
                   "active_from" => ^active_from,
                   "auction_timeout" => 0,
                   "ownership" => %{"current" => ^alice_id, "original" => ^alice_id},
                   "revoke" => %{"tx_hash" => ^alice_revoke_hash},
                   "expire_height" => ^expire1,
                   "approximate_expire_time" => ^approx_expire_time1,
                   "pointers" => []
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
              active: 1,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.InactiveNameExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(Model.InactiveName, name)
          |> Store.put(Model.Tx, Model.tx(index: i - 1, id: <<i::256>>))
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [:passthrough],
         [
           fetch!: fn _state, _hash, _opts -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers_v3: fn _state, _mname -> [] end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [:passthrough], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names", state: "inactive")
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
              active: 1,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.InactiveNameExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(Model.InactiveName, name)
          |> Store.put(Model.Tx, Model.tx(index: i - 1, id: <<i::256>>))
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [:passthrough],
         [
           fetch!: fn _state, _hash, _opts -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {
          Name,
          [],
          [
            pointers_v3: fn _state, _mnme -> [] end,
            ownership: fn _state, _mname -> %{current: nil, original: nil} end,
            stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
          ]
        },
        {:aec_db, [:passthrough], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names", state: "inactive", limit: limit)
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
          active: 1,
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
        |> Store.put(Model.Tx, Model.tx(index: 0, id: <<0::256>>, block_index: {1, 0}, time: 1))
        |> Store.put(Model.Tx, Model.tx(index: 1, id: <<1::256>>, block_index: {1, 1}, time: 2))
        |> Store.put(Model.Tx, Model.tx(index: 2, id: <<2::256>>, block_index: {1, 2}, time: 3))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: block_hash1))
        |> Store.put(Model.Block, Model.block(index: {2, -1}, hash: block_hash2))

      with_mocks [
        {Txs, [:passthrough],
         [
           fetch!: fn _state, _hash, _opts -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers_v3: fn _state, _mnme -> [] end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [:passthrough], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names",
                   state: "inactive",
                   by: by,
                   direction: direction,
                   limit: limit
                 )
                 |> json_response(200)

        assert ^limit = length(names)
      end
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error = "invalid query: by=#{by}"

      assert %{"error" => ^error} = conn |> get("/v3/names", by: by) |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid direction: #{direction}"

      assert %{"error" => ^error} =
               conn
               |> get("/v3/names", state: "inactive", by: by, direction: direction)
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
        [tx1: tx1, tx2: tx2] = transactions
        %{mb0: %{block: mb0}} = blocks
        {:ok, hash0} = mb0 |> :aec_blocks.to_header() |> :aec_headers.hash_header()

        m_auction =
          Model.auction_bid(
            index: plain_name,
            start_height: 0,
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
        [tx1: tx1, tx2: tx2] = transactions

        {:ok, key_hash} =
          blocks[0][:block] |> :aec_blocks.to_header() |> :aec_headers.hash_header()

        m_auction =
          Model.auction_bid(
            index: plain_name,
            start_height: 0,
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
              start_height: 0,
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
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> kb_time end]}
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
                 "last_bid" => last_bid,
                 "name_fee" => 0
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
              start_height: i,
              block_index_txi_idx: {{0, 1}, {0, -1}},
              expire_height: i + 1
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
      limit = 3
      key_hash = <<0::256>>

      store =
        1..21
        |> Enum.reduce(store, fn i, store ->
          plain_name = "玫瑰#{i}.chain"

          auction =
            Model.auction_bid(
              index: plain_name,
              start_height: 0,
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
        assert %{"data" => [auction_bid1 | _rest] = auctions, "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names/auctions", by: by, direction: "forward", limit: limit)
                 |> json_response(200)

        assert %{
                 "name" => "玫瑰1.chain",
                 "info" => %{"approximate_expire_time" => 123}
               } = auction_bid1

        assert ^limit = length(auctions)

        assert %{"data" => [auction_bid4 | _rest], "prev" => prev_url} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        %{"name" => "玫瑰4.chain"} = auction_bid4

        assert %{"data" => ^auctions} =
                 conn
                 |> with_store(store)
                 |> get(prev_url)
                 |> json_response(200)
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

    test "it returns the auction info", %{conn: conn, store: store} do
      plain_name = "asd.chain"
      start_height = 500
      end_height = start_height + 500
      claim_txi_idx1 = {567, -1}
      claim_txi_idx2 = {678, -1}
      claim_txi_idx3 = {788, -1}

      auction_bid =
        Model.auction_bid(
          index: plain_name,
          start_height: start_height,
          block_index_txi_idx: {{start_height, -1}, {788, -1}},
          expire_height: end_height
        )

      {:ok, name_hash_id} = :aens.get_name_hash(plain_name)
      name_hash = Enc.encode(:name, name_hash_id)

      store =
        store
        |> Store.put(Model.AuctionBid, auction_bid)
        |> Store.put(Model.Block, Model.block(index: {start_height, -1}, hash: <<0::256>>))
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, start_height, claim_txi_idx1})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, start_height, claim_txi_idx2})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, start_height, claim_txi_idx3})
        )
        |> Store.put(
          Model.Tx,
          Model.tx(
            index: 788,
            id: <<1::256>>,
            block_index: {start_height, -1}
          )
        )
        |> Store.put(Model.PlainName, Model.plain_name(index: name_hash_id, value: plain_name))

      conn = with_store(conn, store)
      time = 123

      with_mocks([
        {:aec_db, [:passthrough], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> time end]},
        {Format, [],
         [
           to_map: fn _state, Model.tx(index: txi) ->
             %{"tx" => %{"type" => "NameClaimTx"}, "tx_index" => txi}
           end
         ]}
      ]) do
        assert resp =
                 %{
                   "name" => ^plain_name,
                   "name_fee" => 0,
                   "auction_end" => ^end_height,
                   "last_bid" => %{"tx" => %{"ttl" => 51_000, "type" => "NameClaimTx"}},
                   "approximate_expire_time" => 90_000_123,
                   "activation_time" => ^time
                 } =
                 conn
                 |> get("/v3/names/auctions/#{plain_name}")
                 |> json_response(200)

        assert ^resp =
                 conn
                 |> get("/v3/names/auctions/#{name_hash}")
                 |> json_response(200)
      end
    end

    test "it returns error if missing name or hash", %{conn: conn} do
      name = "asd.chain"
      {:ok, name_id} = :aens.get_name_hash(name)
      hash = Enc.encode(:name, name_id)

      error = "not found: #{name}"
      error_hash = "not found: #{hash}"

      assert %{"error" => ^error} =
               conn |> get("/v3/names/auctions/#{name}") |> json_response(404)

      assert %{"error" => ^error_hash} =
               conn |> get("/v3/names/auctions/#{hash}") |> json_response(404)
    end

    test "it returns error if invalid name or hash", %{conn: conn} do
      name = "asd"
      hash = "nm_invalid_hash"

      error = "not found: #{name}.chain"
      error_hash = "not found: #{hash}"

      assert %{"error" => ^error} =
               conn |> get("/v3/names/auctions/#{name}") |> json_response(404)

      assert %{"error" => ^error_hash} =
               conn |> get("/v3/names/auctions/#{hash}") |> json_response(404)
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
              active: 1,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.ActiveName, name)
          |> Store.put(Model.ActiveNameExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(Model.Block, Model.block(index: {i, -1}, hash: key_hash))
        end)
        |> Store.put(Model.Tx, Model.tx(index: 0, id: <<123::256>>))

      with_mocks [
        {Txs, [:passthrough],
         [
           fetch!: fn _state, _hash, _opts -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers_v3: fn _state, _mnme -> [] end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names")
                 |> json_response(200)

        assert @default_limit = length(names)
      end
    end

    test "on v3, it gets active and inactive names, except those in auction, with default limit",
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
              active: 1,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.ActiveName, name)
          |> Store.put(Model.ActiveNameExpiration, Model.expiration(index: {i, plain_name}))
          |> Store.put(Model.Tx, Model.tx(index: i - 1, id: <<123::256>>))
          |> Store.put(Model.Block, Model.block(index: {i, -1}, hash: key_hash))
        end)

      with_mocks [
        {Txs, [:passthrough],
         [
           fetch!: fn _state, _hash, _opts -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [:passthrough],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]},
        {:aec_db, [:passthrough], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names, "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names")
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
              active: 1,
              expire: 1,
              revoke: {{0, 0}, {0, -1}},
              auction_timeout: 1
            )

          store
          |> Store.put(Model.ActiveName, name)
          |> Store.put(Model.Tx, Model.tx(index: i - 1, id: <<i::256>>))
          |> Store.put(Model.ActiveNameExpiration, Model.expiration(index: {i, plain_name}))
        end)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [:passthrough],
         [
           fetch!: fn _state, _hash, _opts -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers_v3: fn _state, _mname -> [] end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [:passthrough], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names", limit: limit)
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
          active: 1,
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
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))
        |> Store.put(Model.Block, Model.block(index: {2, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash, _opts -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers_v3: fn _state, _mnme -> [] end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end,
           stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
         ]},
        {:aec_db, [:passthrough], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => [name1, name2, name3], "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names", direction: "forward", owned_by: owner_id)
                 |> json_response(200)

        assert %{"name" => ^first_name} = name1
        assert %{"name" => ^second_name} = name2
        assert %{"name" => ^third_name} = name3

        assert %{"data" => [name1, name2], "next" => _next} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names",
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
          active: 1,
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
        {Name, [:passthrough],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname ->
             orig = {:id, :account, owner_pk}
             %{current: orig, original: orig}
           end
         ]},
        {:aec_db, [], [get_header: fn ^key_hash -> :block end]},
        {:aec_headers, [:passthrough], [time_in_msecs: fn :block -> 123 end]}
      ] do
        assert %{"data" => owned_names} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names",
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

    test "it gets names filtered by prefix when by=name", %{conn: conn, store: store} do
      first_name = "x.chain"
      second_name = "o1#{first_name}"
      third_name = "o3#{first_name}"
      fourth_name = "x.chain"
      key_hash = <<0::256>>

      inactive_name =
        Model.name(
          index: first_name,
          active: 1,
          expire: 3,
          revoke: nil,
          owner: <<0::256>>,
          auction_timeout: 1
        )

      active_name = Model.name(inactive_name, index: third_name)

      store =
        store
        |> Store.put(Model.InactiveName, inactive_name)
        |> Store.put(Model.InactiveName, Model.name(inactive_name, index: second_name))
        |> Store.put(Model.ActiveName, Model.name(inactive_name, index: fourth_name))
        |> Store.put(Model.ActiveName, active_name)
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: key_hash))

      with_mocks [
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [:passthrough], [pointers: fn _state, _mnme -> %{} end]},
        {:aec_db, [], [get_header: fn _block_hash -> :block end]},
        {:aec_headers, [], [time_in_msecs: fn :block -> 123 end]},
        {:aec_hard_forks, [], [protocol_effective_at_height: fn _height -> :lima end]},
        {:aec_governance, [:passthrough], [name_claim_fee: fn _name, :lima -> 1 end]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names", by: "name", prefix: "o")
                 |> json_response(200)

        assert [^third_name, ^second_name] =
                 Enum.map(names, fn %{"name" => name} -> name end)

        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v3/names", by: "name", prefix: "O")
                 |> json_response(200)

        assert [^third_name, ^second_name] =
                 Enum.map(names, fn %{"name" => name} -> name end)
      end
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error = "invalid query: by=#{by}"

      assert %{"error" => ^error} = conn |> get("/v3/names?by=#{by}") |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid direction: #{direction}"

      assert %{"error" => ^error} =
               conn |> get("/v3/names?by=#{by}&direction=#{direction}") |> json_response(400)
    end

    test "renders error when parameter owned_by is not an address", %{conn: conn} do
      owned_by = "invalid_address"
      error = "invalid id: #{owned_by}"

      assert %{"error" => ^error} =
               conn |> get("/v3/names?owned_by=#{owned_by}") |> json_response(400)
    end
  end

  describe "names_count" do
    test "get names count", %{conn: conn, store: store} do
      first_owner_pk = <<123::256>>
      second_owner_pk = <<456::256>>
      first_owner_id = Enc.encode(:account_pubkey, first_owner_pk)
      second_owner_id = Enc.encode(:account_pubkey, second_owner_pk)

      store =
        store
        |> Store.put(Model.TotalStat, Model.total_stat(index: 1, active_names: 27))
        |> Store.put(
          Model.AccountNamesCount,
          Model.account_names_count(index: first_owner_pk, count: 13)
        )
        |> Store.put(
          Model.AccountNamesCount,
          Model.account_names_count(index: second_owner_pk, count: 14)
        )

      assert 27 =
               conn
               |> with_store(store)
               |> get("/v3/names/count")
               |> json_response(200)

      assert 13 =
               conn
               |> with_store(store)
               |> get("/v3/names/count", owned_by: first_owner_id)
               |> json_response(200)

      assert 14 =
               conn
               |> with_store(store)
               |> get("/v3/names/count", owned_by: second_owner_id)
               |> json_response(200)
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
        %{block: block, txs: [tx1, tx2]} = blocks[:mb]
        {:id, :account, alice_pk} = accounts[:alice]
        active_from = blocks[:mb][:height]
        expire = 10_000
        {:ok, block_hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()

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
          |> Store.put(Model.Block, Model.block(index: {active_from, -1}, hash: block_hash))
          |> Store.put(Model.Block, Model.block(index: {123, -1}, hash: block_hash))

        assert %{
                 "name" => ^name,
                 "active" => true,
                 "auction" => nil
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/names/#{name}")
                 |> json_response(200)
      end
    end

    test "get active name info by name with different case", %{conn: conn, store: store} do
      name = "bigname123456.chain"
      {:ok, name_hash_id} = :aens.get_name_hash(name)
      mixed_case_name = "bIGnAME123456.chain"

      with_blockchain %{alice: 1_000},
        mb: [
          tx1: name_tx(:name_claim_tx, :alice, name),
          tx2: name_tx(:name_update_tx, :alice, name)
        ] do
        %{block: block, txs: [tx1, tx2]} = blocks[:mb]
        {:id, :account, alice_pk} = accounts[:alice]
        active_from = blocks[:mb][:height]
        expire = 10_000
        {:ok, block_hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()

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
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash_id, value: name))
          |> Store.put(Model.Block, Model.block(index: {active_from, -1}, hash: block_hash))
          |> Store.put(Model.Block, Model.block(index: {123, -1}, hash: block_hash))

        assert %{
                 "name" => ^name,
                 "active" => true,
                 "auction" => nil
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/names/#{mixed_case_name}")
                 |> json_response(200)
      end
    end

    test "get name claimed with ga_meta_tx", %{conn: conn, store: store} do
      buyer_pk = TS.address(0)
      owner_pk = TS.address(1)
      plain_name = "gametaclaimed.chain"

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
        %{block: block, txs: [tx]} = blocks[:mb]
        {:ok, block_hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()
        active_height = blocks[:mb][:height]

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
          |> Store.put(Model.Block, Model.block(index: {active_height, -1}, hash: block_hash))
          |> Store.put(Model.Block, Model.block(index: {123, -1}, hash: block_hash))

        assert %{
                 "name" => ^plain_name,
                 "active" => true,
                 "auction" => nil
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/names/#{plain_name}")
                 |> json_response(200)
      end
    end

    test "get name claimed with paying_for_tx", %{conn: conn, store: store} do
      buyer_pk = TS.address(2)
      owner_pk = TS.address(3)
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
        %{block: block, txs: [tx]} = blocks[:mb]
        {:ok, block_hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()

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
          |> Store.put(Model.Block, Model.block(index: {2, -1}, hash: block_hash))

        assert %{
                 "name" => ^plain_name,
                 "active" => true,
                 "auction" => nil
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/names/#{plain_name}")
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
        start_height = blocks[:mb][:height]
        claim_txi = 100
        expire = 10_000
        bid_txi = Enum.random(100..1_000)
        {:ok, block_hash} = mb_block |> :aec_blocks.to_header() |> :aec_headers.hash_header()

        bid_expire =
          :aec_governance.name_claim_bid_timeout(name, :aec_hard_forks.protocol_vsn(:lima) + 1)

        store =
          store
          |> Store.put(
            Model.InactiveName,
            Model.name(
              index: name,
              owner: alice_pk,
              active: start_height,
              expire: expire,
              owner: alice_pk
            )
          )
          |> Store.put(
            Model.AuctionBid,
            Model.auction_bid(
              index: name,
              start_height: start_height,
              block_index_txi_idx: {{start_height, -1}, bid_txi},
              expire_height: bid_expire
            )
          )
          |> Store.put(
            Model.NameClaim,
            Model.name_claim(index: {name, start_height, {claim_txi, -1}})
          )
          |> Store.put(
            Model.AuctionBidClaim,
            Model.auction_bid_claim(index: {name, start_height, {bid_txi, -1}})
          )
          |> Store.put(Model.AuctionOwner, Model.owner(index: {alice_pk, name}))
          |> Store.put(Model.AuctionExpiration, Model.expiration(index: {bid_expire, name}))
          |> Store.put(
            Model.Tx,
            Model.tx(index: bid_txi, id: :aetx_sign.hash(tx), block_index: {1, 1})
          )
          |> Store.put(
            Model.Block,
            Model.block(index: {start_height, -1}, hash: mb_hash, tx_index: 2)
          )
          |> Store.put(
            Model.Block,
            Model.block(index: {bid_expire, -1}, hash: mb_hash, tx_index: 2)
          )
          |> Store.put(Model.Block, Model.block(index: {expire, -1}, hash: block_hash))

        assert %{
                 "name" => ^name,
                 "active" => false,
                 "auction" => %{
                   "auction_end" => ^bid_expire,
                   "approximate_expire_time" => ^block_time
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/names/#{name}")
                 |> json_response(200)
      end
    end

    test "get name info by encoded hash ", %{conn: conn, store: store} do
      hash = <<789::256>>
      name = "some-name.chain"
      owner_pk = <<1::256>>
      owner_id = :aeser_id.create(:account, owner_pk)

      with_blockchain %{}, mb: [] do
        %{block: block} = blocks[:mb]
        {:ok, block_hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()

        with_mocks [
          {Name, [:passthrough],
           [
             locate_bid: fn _state, ^name -> nil end,
             pointers: fn _state, _name_model -> %{} end,
             ownership: fn _state, _name -> %{original: owner_id, current: owner_id} end,
             stream_nested_resource: fn _state, _table, _plain_name, _active -> [] end
           ]}
        ] do
          store =
            store
            |> Store.put(Model.PlainName, Model.plain_name(index: hash, value: name))
            |> Store.put(
              Model.ActiveName,
              Model.name(index: name, active: 1, expire: 0, owner: owner_pk)
            )
            |> Store.put(Model.Block, Model.block(index: {0, -1}, hash: block_hash))

          assert %{"active" => true, "name" => ^name} =
                   conn |> with_store(store) |> get("/v3/names/#{hash}") |> json_response(200)
        end
      end
    end

    test "renders error when no such name is present", %{conn: conn} do
      name = "no--such--name--in--the--chain.chain"
      error = "not found: #{name}"

      with_mocks [{Name, [], [locate: fn _state, ^name -> nil end]}] do
        assert %{"error" => ^error} = conn |> get("/v3/names/#{name}") |> json_response(404)
      end
    end
  end

  describe "pointees" do
    test "get pointees for valid public key", %{conn: conn, store: store} do
      account_pk = <<0::256>>
      account_id = :aeser_id.create(:account, account_pk)
      account = Enc.encode(:account_pubkey, account_pk)
      plain_name1 = "a.chain"
      name_hash1 = <<1::256>>
      name_id1 = :aeser_id.create(:name, name_hash1)
      plain_name2 = "b.chain"
      name_hash2 = <<2::256>>
      name_id2 = :aeser_id.create(:name, name_hash2)
      plain_name3 = "c.chain"
      name_hash3 = <<3::256>>
      name_id3 = :aeser_id.create(:name, name_hash3)

      store =
        store
        |> Store.put(
          Model.Pointee,
          Model.pointee(index: {account_pk, {{200, 1}, {500, -1}}, "some-key-1"})
        )
        |> Store.put(Model.Tx, Model.tx(index: 500, id: <<0::256>>))
        |> Store.put(Model.PlainName, Model.plain_name(index: name_hash1, value: plain_name1))
        |> Store.put(
          Model.Pointee,
          Model.pointee(index: {account_pk, {{200, 2}, {501, -1}}, "some-key-2"})
        )
        |> Store.put(Model.Tx, Model.tx(index: 501, id: <<1::256>>))
        |> Store.put(Model.PlainName, Model.plain_name(index: name_hash2, value: plain_name2))
        |> Store.put(
          Model.Pointee,
          Model.pointee(index: {account_pk, {{200, 2}, {502, -1}}, "some-key-3"})
        )
        |> Store.put(Model.Tx, Model.tx(index: 502, id: <<2::256>>))
        |> Store.put(Model.PlainName, Model.plain_name(index: name_hash3, value: plain_name3))
        |> Store.put(Model.ActiveName, Model.name(index: plain_name3))

      {:ok, aetx1} =
        :aens_update_tx.new(%{
          account_id: account_id,
          nonce: 111,
          name_id: name_id1,
          name_ttl: 1_111,
          pointers: [],
          client_ttl: 11_111,
          fee: 111_111,
          ttl: 1_111_111
        })

      {:name_update_tx, tx1} = :aetx.specialize_type(aetx1)

      {:ok, aetx2} =
        :aens_update_tx.new(%{
          account_id: account_id,
          nonce: 222,
          name_id: name_id2,
          name_ttl: 2_222,
          pointers: [],
          client_ttl: 22_222,
          fee: 222_222,
          ttl: 2_222_222
        })

      {:name_update_tx, tx2} = :aetx.specialize_type(aetx2)

      {:ok, aetx3} =
        :aens_update_tx.new(%{
          account_id: account_id,
          nonce: 333,
          name_id: name_id3,
          name_ttl: 3_333,
          pointers: [],
          client_ttl: 33_333,
          fee: 333_333,
          ttl: 3_333_333
        })

      {:name_update_tx, tx3} = :aetx.specialize_type(aetx3)

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             <<0::256>> -> {"", :name_update_tx, :aetx_sign.new(aetx1, []), tx1}
             <<1::256>> -> {"", :name_update_tx, :aetx_sign.new(aetx2, []), tx2}
             <<2::256>> -> {"", :name_update_tx, :aetx_sign.new(aetx3, []), tx3}
           end,
           get_block_time: fn _block_hash ->
             1
           end
         ]}
      ] do
        assert %{"data" => [pointee3, pointee2, pointee1]} =
                 conn
                 |> with_store(store)
                 |> get("/v3/accounts/#{account}/names/pointees")
                 |> json_response(200)

        assert %{"name" => ^plain_name1, "active" => false} = pointee1
        assert %{"name" => ^plain_name2, "active" => false} = pointee2
        assert %{"name" => ^plain_name3, "active" => true} = pointee3
      end
    end

    test "renders error when the key is invalid", %{conn: conn, store: store} do
      id = "ak_invalidkey"
      error = "invalid id: #{id}"

      store =
        store
        |> Store.put(Model.Block, Model.block(index: {123, 0}, hash: "mb1-hash"))

      assert %{"error" => ^error} =
               conn |> with_store(store) |> get("/v2/names/#{id}/pointees") |> json_response(400)
    end
  end

  describe "pointees_v2" do
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

    test "renders error when the key is invalid", %{conn: conn, store: store} do
      id = "ak_invalidkey"
      error = "invalid id: #{id}"

      store =
        store
        |> Store.put(Model.Block, Model.block(index: {123, 0}, hash: "mb1-hash"))

      assert %{"error" => ^error} =
               conn |> with_store(store) |> get("/v2/names/#{id}/pointees") |> json_response(400)
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
      start_height = 1000
      claim_txi_idx1 = {567, -1}
      claim_txi_idx2 = {678, -1}
      claim_txi_idx3 = {788, -1}

      auction_bid =
        Model.auction_bid(
          index: plain_name,
          start_height: start_height
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
          Model.auction_bid_claim(index: {plain_name, start_height, claim_txi_idx1})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, start_height, claim_txi_idx2})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, start_height, claim_txi_idx3})
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

      {:ok, claim_aetx0} =
        :aens_claim_tx.new(%{
          account_id: :aeser_id.create(:account, TS.address(1)),
          nonce: 1,
          name: plain_name,
          name_salt: 1_110,
          name_fee: 11_110,
          fee: 111_110,
          ttl: 1_111_110
        })

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
             <<500::256>> ->
               {:name_claim_tx, tx} = :aetx.specialize_type(claim_aetx0)
               {"", :name_claim_tx, :aetx_sign.new(claim_aetx0, []), tx}

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
        [claim0_hash, claim1_hash, update1_hash, transfer_hash, revoke_hash] =
          for i <- 0..4, do: Enc.encode(:tx_hash, <<500 + i::256>>)

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

        assert %{"data" => [update1, claim1, claim0], "prev" => prev_url} =
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

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^claim0_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 1}
               } = claim0

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

      {:ok, claim_aetx0} =
        :aens_claim_tx.new(%{
          account_id: :aeser_id.create(:account, TS.address(1)),
          nonce: 1,
          name: plain_name,
          name_salt: 1_110,
          name_fee: 11_110,
          fee: 111_110,
          ttl: 1_111_110
        })

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
             <<500::256>> ->
               {:name_claim_tx, tx} = :aetx.specialize_type(claim_aetx0)
               {"", :name_claim_tx, :aetx_sign.new(claim_aetx0, []), tx}

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
        [claim0_hash, claim1_hash, update1_hash, transfer_hash, revoke_hash] =
          for i <- 0..4, do: Enc.encode(:tx_hash, <<500 + i::256>>)

        [claim2_hash, update2_hash] = for i <- 1..2, do: Enc.encode(:tx_hash, <<600 + i::256>>)

        assert %{
                 "data" => [claim0, claim1, update1, transfer, revoke] = history,
                 "next" => next_url
               } =
                 conn
                 |> get("/v2/names/#{plain_name}/history", direction: "forward", limit: 5)
                 |> json_response(200)

        refute is_nil(next_url)

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^claim0_hash,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 1}
               } = claim0

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
      start_height = 500
      claim_txi_idx1 = {567, -1}
      claim_txi_idx2 = {678, -1}
      claim_txi_idx3 = {788, -1}

      auction_bid =
        Model.auction_bid(
          index: plain_name,
          start_height: start_height
        )

      {:ok, name_hash_id} = :aens.get_name_hash(plain_name)
      name_hash = Enc.encode(:name, name_hash_id)

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
          Model.auction_bid_claim(index: {plain_name, start_height, claim_txi_idx1})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, start_height, claim_txi_idx2})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name, start_height, claim_txi_idx3})
        )
        |> Store.put(Model.PlainName, Model.plain_name(index: name_hash_id, value: plain_name))

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

        assert %{"data" => [^claim1, ^claim2], "next" => hash_next_url} =
                 conn
                 |> get("/v3/names/auctions/#{name_hash}/claims", limit: 2, direction: "forward")
                 |> json_response(200)

        refute is_nil(next_url)
        refute is_nil(hash_next_url)
        assert %{"height" => 123, "tx" => %{"fee" => 111_111}} = claim1
        assert %{"height" => 123, "tx" => %{"fee" => 222_222}} = claim2

        assert %{"data" => [claim3], "prev" => prev_url} =
                 conn |> get(next_url) |> json_response(200)

        assert %{"data" => [^claim3], "prev" => hash_prev_url} =
                 conn |> get(hash_next_url) |> json_response(200)

        refute is_nil(prev_url)
        refute is_nil(hash_prev_url)
        assert %{"height" => 124, "tx" => %{"fee" => 333_333}} = claim3

        assert %{"data" => ^claims} = conn |> get(prev_url) |> json_response(200)
        assert %{"data" => ^claims} = conn |> get(hash_prev_url) |> json_response(200)
      end
    end
  end

  describe "name_v2" do
    test "it returns an active/inactive name", %{conn: conn, store: store} do
      name = "foo.chain"

      with_blockchain %{alice: 1_000},
        mb: [
          tx1: name_tx(:name_claim_tx, :alice, name),
          tx2: name_tx(:name_update_tx, :alice, name)
        ] do
        %{block: block, txs: [tx1, tx2]} = blocks[:mb]
        {:id, :account, alice_pk} = accounts[:alice]
        # alice_pk = <<0::256>>
        alice_id = encode(:account_pubkey, alice_pk)
        oracle_id = encode(:oracle_pubkey, alice_pk)
        active_from = 10
        expire = 10_000
        {:ok, block_hash} = block |> :aec_blocks.to_header() |> :aec_headers.hash_header()
        # block_hash = <<1::256>>

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
          |> Store.put(Model.Block, Model.block(index: {123, -1}, hash: block_hash))

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

    test "it doesn't return an auction bid", %{conn: conn} do
      %{"error" => _error_msg} =
        conn
        |> get("/v2/names/foo.chain")
        |> json_response(404)
    end
  end

  describe "account_claims" do
    test "gets all account claims", %{conn: conn} do
      store = MemStore.new(NullStore.new())
      account_id = TS.address(0)
      specialized_account_id = :aeser_id.create(:account, account_id)
      account_pk = :aeapi.format_account_pubkey(account_id)
      plain_name1 = new_name()
      plain_name2 = new_name()
      plain_name3 = new_name()

      active_from1 = 5
      kbi1 = 5
      active_from2 = 8
      kbi2 = 8

      {:ok, claim_aetx0} =
        :aens_claim_tx.new(%{
          account_id: specialized_account_id,
          nonce: 1,
          name: plain_name1,
          name_salt: 1_110,
          name_fee: 11_110,
          fee: 111_110,
          ttl: 1_111_110
        })

      {:ok, claim_aetx1} =
        :aens_claim_tx.new(%{
          account_id: specialized_account_id,
          nonce: 11,
          name: plain_name1,
          name_salt: 1_111,
          name_fee: 11_111,
          fee: 111_111,
          ttl: 1_111_111
        })

      {:ok, claim_aetx2} =
        :aens_claim_tx.new(%{
          account_id: specialized_account_id,
          nonce: 21,
          name: plain_name2,
          name_salt: 2_222,
          name_fee: 22_222,
          fee: 222_222,
          ttl: 2_222_222
        })

      {:ok, call_aetx2} =
        :aect_call_tx.new(%{
          caller_id: specialized_account_id,
          nonce: 21,
          contract_id: :aeser_id.create(:contract, TS.address(1)),
          abi_version: 1,
          fee: 222_222,
          amount: 12,
          gas: 1_111,
          gas_price: 1_111,
          call_data: "",
          ttl: 2_222_222
        })

      {:ok, call_aetx3} =
        :aect_call_tx.new(%{
          caller_id: specialized_account_id,
          nonce: 22,
          contract_id: :aeser_id.create(:contract, TS.address(1)),
          abi_version: 1,
          fee: 222_222,
          amount: 12,
          gas: 1_111,
          gas_price: 1_111,
          call_data: "",
          ttl: 2_222_222
        })

      {:ok, claim_aetx3} =
        :aens_claim_tx.new(%{
          account_id: specialized_account_id,
          nonce: 31,
          name: plain_name2,
          name_salt: 3_333,
          name_fee: 33_333,
          fee: 333_333,
          ttl: 3_333_333
        })

      {:ok, call_aetx4} =
        :aect_call_tx.new(%{
          caller_id: specialized_account_id,
          nonce: 23,
          contract_id: :aeser_id.create(:contract, TS.address(1)),
          abi_version: 1,
          fee: 222_222,
          amount: 12,
          gas: 1_111,
          gas_price: 1_111,
          call_data: "",
          ttl: 2_222_222
        })

      {:ok, claim_aetx4} =
        :aens_claim_tx.new(%{
          account_id: specialized_account_id,
          nonce: 41,
          name: plain_name3,
          name_salt: 4_444,
          name_fee: 44_444,
          fee: 444_444,
          ttl: 4_444_444
        })

      {:ok, call_aetx5} =
        :aect_call_tx.new(%{
          caller_id: specialized_account_id,
          nonce: 24,
          contract_id: :aeser_id.create(:contract, TS.address(1)),
          abi_version: 1,
          fee: 222_222,
          amount: 12,
          gas: 1_111,
          gas_price: 1_111,
          call_data: "",
          ttl: 2_222_222
        })

      {:ok, claim_aetx5} =
        :aens_claim_tx.new(%{
          account_id: specialized_account_id,
          nonce: 51,
          name: plain_name3,
          name_salt: 5_555,
          name_fee: 55_555,
          fee: 555_555,
          ttl: 5_555_555
        })

      store =
        store
        # |> name_history_store(active_from1, active_from2, kbi1, kbi2, expired_at, plain_name)
        |> Store.put(
          Model.Block,
          Model.block(index: {5, -1}, hash: <<500::256>>, tx_index: 500)
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {7, -1}, hash: <<501::256>>, tx_index: 550)
        )
        |> Store.put(
          Model.Block,
          Model.block(index: {8, -1}, hash: <<600::256>>, tx_index: 600)
        )
        |> Store.put(
          Model.NameClaim,
          Model.name_claim(index: {plain_name1, active_from1, {500, -1}})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name1, active_from1, {501, -1}})
        )
        |> Store.put(
          Model.NameClaim,
          Model.name_claim(index: {plain_name2, active_from2, {601, -1}})
        )
        |> Store.put(
          Model.AuctionBidClaim,
          Model.auction_bid_claim(index: {plain_name2, active_from2, {602, 1}})
        )
        |> Store.put(
          Model.NameClaim,
          Model.auction_bid_claim(index: {plain_name3, active_from2, {603, 1}})
        )
        |> Store.put(
          Model.NameClaim,
          Model.name_claim(index: {plain_name3, active_from2, {604, 1}})
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:name_claim_tx, 1, account_id, 500})
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:name_claim_tx, 1, account_id, 501})
        )
        |> Store.put(
          Model.Field,
          Model.field(index: {:name_claim_tx, 1, account_id, 601})
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: 500, block_index: {5, 4}, id: <<500::256>>)
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: 501, block_index: {5, 6}, id: <<501::256>>)
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: 601, block_index: {8, 2}, id: <<601::256>>)
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: 602, block_index: {8, 2}, id: <<602::256>>)
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: 603, block_index: {8, 2}, id: <<603::256>>)
        )
        |> Store.put(
          Model.Tx,
          Model.tx(index: 604, block_index: {8, 2}, id: <<604::256>>)
        )
        |> Store.put(
          Model.IntContractCall,
          Model.int_contract_call(index: {601, 0}, tx: claim_aetx2)
        )
        |> Store.put(
          Model.IntContractCall,
          Model.int_contract_call(index: {602, 1}, tx: claim_aetx3)
        )
        |> Store.put(
          Model.IntContractCall,
          Model.int_contract_call(index: {603, 1}, tx: claim_aetx4)
        )
        |> Store.put(
          Model.IntContractCall,
          Model.int_contract_call(index: {604, 1}, tx: claim_aetx5)
        )
        |> Store.put(
          Model.IdFnameIntContractCall,
          Model.id_fname_int_contract_call(index: {account_id, "AENS.claim", 1, 602, 1})
        )
        |> Store.put(
          Model.IdFnameIntContractCall,
          Model.id_fname_int_contract_call(index: {account_id, "AENS.claim", 1, 603, 1})
        )
        |> Store.put(
          Model.IdFnameIntContractCall,
          Model.id_fname_int_contract_call(index: {account_id, "AENS.claim", 1, 604, 1})
        )
        |> Store.put(
          Model.ActiveName,
          Model.name(
            index: plain_name1,
            owner: account_id,
            active: active_from1,
            expire: 1_111_111
          )
        )
        |> Store.put(
          Model.ActiveName,
          Model.name(
            index: plain_name2,
            owner: account_id,
            active: active_from2,
            expire: 2_222_222
          )
        )
        |> Store.put(
          Model.ActiveName,
          Model.name(
            index: plain_name3,
            owner: account_id,
            active: active_from2,
            expire: 3_333_333
          )
        )
        |> Store.put(
          Model.InactiveName,
          Model.name(
            index: plain_name3,
            owner: account_id,
            active: active_from2,
            expire: 3_333_333
          )
        )

      conn = with_store(conn, store)

      with_mocks [
        {Db, [:passthrough],
         [
           get_tx: fn
             <<500::256>> ->
               :aetx.specialize_type(claim_aetx0)

             <<501::256>> ->
               :aetx.specialize_type(claim_aetx1)

             <<601::256>> ->
               :aetx.specialize_type(call_aetx2)

             <<602::256>> ->
               :aetx.specialize_type(call_aetx3)

             <<603::256>> ->
               :aetx.specialize_type(call_aetx4)

             <<604::256>> ->
               :aetx.specialize_type(call_aetx5)
           end,
           get_tx_data: fn
             <<500::256>> ->
               tx = claim_aetx0 |> :aetx.specialize_type() |> elem(1)
               {<<1::256>>, :name_claim_tx, %{}, tx}

             <<501::256>> ->
               tx = claim_aetx1 |> :aetx.specialize_type() |> elem(1)
               {<<2::256>>, :name_claim_tx, %{}, tx}

             <<601::256>> ->
               tx = claim_aetx2 |> :aetx.specialize_type() |> elem(1)
               {<<3::256>>, :name_claim_tx, %{}, tx}

             <<602::256>> ->
               tx = call_aetx3
               {<<4::256>>, :contract_call_tx, %{}, tx}

             <<603::256>> ->
               tx = call_aetx4
               {<<5::256>>, :contract_call_tx, %{}, tx}

             <<604::256>> ->
               tx = call_aetx5
               {<<6::256>>, :contract_call_tx, %{}, tx}
           end
         ]}
      ] do
        tx_hash1 = :aeapi.format_tx_hash(<<500::256>>)
        tx_hash2 = :aeapi.format_tx_hash(<<501::256>>)
        tx_hash3 = :aeapi.format_tx_hash(<<601::256>>)
        tx_hash4 = :aeapi.format_tx_hash(<<602::256>>)
        tx_hash5 = :aeapi.format_tx_hash(<<603::256>>)
        tx_hash6 = :aeapi.format_tx_hash(<<604::256>>)

        assert %{"data" => data, "prev" => nil, "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v3/accounts/#{account_pk}/names/claims", limit: 4)
                 |> json_response(200)

        assert length(data) == 4

        assert %{
                 "active_from" => ^active_from2,
                 "height" => ^kbi2,
                 "source_tx_type" => "ContractCallTx",
                 "source_tx_hash" => ^tx_hash6,
                 "internal_source" => true,
                 "tx" => %{"nonce" => 51}
               } = Enum.at(data, 0)

        assert %{
                 "active_from" => ^active_from2,
                 "height" => ^kbi2,
                 "source_tx_type" => "ContractCallTx",
                 "source_tx_hash" => ^tx_hash5,
                 "internal_source" => true,
                 "tx" => %{"nonce" => 41}
               } = Enum.at(data, 1)

        assert %{
                 "active_from" => ^active_from2,
                 "height" => ^kbi2,
                 "source_tx_type" => "ContractCallTx",
                 "source_tx_hash" => ^tx_hash4,
                 "internal_source" => true,
                 "tx" => %{"nonce" => 31}
               } = Enum.at(data, 2)

        assert %{
                 "active_from" => ^active_from2,
                 "height" => ^kbi2,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^tx_hash3,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 21}
               } = Enum.at(data, 3)

        assert %{"next" => nil, "prev" => prev_url, "data" => next_data} =
                 conn
                 |> get(next_url)
                 |> json_response(200)

        assert length(next_data) == 2

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^tx_hash2,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 11}
               } =
                 Enum.at(next_data, 0)

        assert %{
                 "active_from" => ^active_from1,
                 "height" => ^kbi1,
                 "source_tx_type" => "NameClaimTx",
                 "source_tx_hash" => ^tx_hash1,
                 "internal_source" => false,
                 "tx" => %{"nonce" => 1}
               } =
                 Enum.at(next_data, 1)

        assert %{"next" => ^next_url, "prev" => nil, "data" => ^data} =
                 conn
                 |> get(prev_url)
                 |> json_response(200)

        assert %{"next" => nil, "prev" => nil, "data" => claims_at_height8} =
                 conn
                 |> get("/v3/accounts/#{account_pk}/names/claims", scope: "gen:7-9")
                 |> json_response(200)

        Enum.each(claims_at_height8, fn %{"active_from" => active_from} ->
          assert active_from == 8
        end)
      end
    end
  end

  defp name_history_store(store, active_from1, active_from2, kbi1, kbi2, expired_at, plain_name) do
    claim0 = {500, -1}
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
    |> Store.put(
      Model.AuctionBidClaim,
      Model.auction_bid_claim(index: {plain_name, active_from1, claim0})
    )
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
      Enum.reduce(0..4, store, fn i, store ->
        Store.put(
          store,
          Model.Tx,
          Model.tx(index: 500 + i, block_index: {kbi1, i}, id: <<500 + i::256>>)
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
    |> Store.put(
      Model.Block,
      Model.block(index: {kbi1, -1}, hash: "kb#{kbi1}-hash", tx_index: 500)
    )
    |> Store.put(
      Model.Block,
      Model.block(index: {kbi1, 0}, hash: "mb#{kbi1}-hash")
    )
    |> Store.put(
      Model.Block,
      Model.block(index: {kbi2, -1}, hash: "kb#{kbi2}-hash", tx_index: 601)
    )
    |> Store.put(
      Model.Block,
      Model.block(index: {kbi2, 0}, hash: "mb#{kbi2}-hash")
    )
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
