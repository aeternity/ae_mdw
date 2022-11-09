defmodule AeMdwWeb.NameControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Model.ActiveName
  alias AeMdw.Db.Model.ActiveNameActivation
  alias AeMdw.Db.Model.ActiveNameExpiration
  alias AeMdw.Db.Model.AuctionBid
  alias AeMdw.Db.Model.AuctionExpiration
  alias AeMdw.Db.Model.InactiveName
  alias AeMdw.Db.Model.InactiveNameOwner
  alias AeMdw.Db.Model.InactiveNameExpiration
  alias AeMdw.Db.Model.Tx
  alias AeMdw.Db.Name
  alias AeMdw.Db.Store
  alias AeMdw.Database
  alias AeMdw.Node.Db
  alias AeMdw.Validate
  alias AeMdw.TestSamples, as: TS
  alias AeMdw.Txs

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, name_tx: 3]

  import Mock

  require Model

  @default_limit 10

  setup _ do
    height_name =
      for i <- 100..121, into: %{}, do: {i, "name#{Enum.random(1_000_000..9_999_999)}.chain"}

    {:ok, height_name: height_name}
  end

  describe "active_names" do
    test "renders active names with detailed info", %{conn: conn, store: store} do
      alice_name = "aliceinchains.chain"
      bob_name = "bobandmarley.chain"

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

        store =
          store
          |> Store.put(
            Model.ActiveName,
            Model.name(
              index: alice_name,
              owner: alice_pk,
              active: active_from,
              claims: [{{10, 0}, 1}],
              transfers: [{{10, 0}, 12}],
              updates: [{{10, 0}, 2}],
              expire: expire1
            )
          )
          |> Store.put(
            Model.ActiveName,
            Model.name(
              index: bob_name,
              owner: bob_pk,
              active: active_from,
              claims: [{{10, 1}, 3}],
              transfers: [{{10, 0}, 14}],
              updates: [{{10, 2}, 4}],
              expire: expire2
            )
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

        assert %{"data" => names} =
                 conn
                 |> with_store(store)
                 |> get("/v2/names", state: "active")
                 |> json_response(200)

        assert [
                 %{
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
                     "expire_height" => ^expire2
                   },
                   "previous" => [],
                   "status" => "name"
                 },
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
                     "expire_height" => ^expire1
                   },
                   "previous" => [],
                   "status" => "name"
                 }
               ] = names
      end
    end

    test "get active names with default limit", %{conn: conn, height_name: height_name} do
      with_mocks [
        {Database, [],
         [
           last_key: fn ActiveNameExpiration -> {:ok, {121, height_name[121]}} end,
           next_key: fn ActiveNameExpiration, _exp_key -> :none end,
           prev_key: fn ActiveNameExpiration, {height, _name} ->
             {:ok, {height - 1, height_name[height - 1]}}
           end,
           get: fn
             Tx, key ->
               {:ok, Model.tx(index: key, id: 0, block_index: {0, 0}, time: 0)}

             ActiveNameExpiration, _key ->
               :not_found

             AuctionBid, _plain_name ->
               :not_found

             ActiveName, plain_name ->
               expire =
                 Enum.find_value(height_name, fn {height, name} ->
                   if name == plain_name, do: height
                 end)

               {:ok,
                Model.name(
                  index: plain_name,
                  active: expire - 10,
                  expire: expire,
                  claims: [{{expire - 10, 0}, 0}],
                  updates: [],
                  transfers: [],
                  revoke: nil,
                  auction_timeout: 1
                )}
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mname -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names, "next" => next} =
                 conn
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

    test "get active names with parameters by=name, direction=forward and limit=3", %{conn: conn} do
      by = "name"
      direction = "forward"
      limit = 3

      with_mocks [
        {Database, [],
         [
           first_key: fn ActiveName -> {:ok, TS.plain_name(0)} end,
           next_key: fn ActiveName, _exp_key -> {:ok, TS.plain_name(1)} end,
           prev_key: fn ActiveName, nil -> :none end,
           get: fn
             ActiveName, _plain_name ->
               {:ok,
                Model.name(
                  active: true,
                  expire: 1,
                  claims: [{{0, 0}, 0}],
                  updates: [],
                  transfers: [],
                  revoke: {{0, 0}, 0},
                  auction_timeout: 1
                )}

             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mname -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> get("/v2/names", state: "active", by: by, direction: direction, limit: limit)
                 |> json_response(200)

        assert ^limit = length(names)
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

    test "it renders active names with ga_meta transactions", %{conn: conn} do
      {_exp, plain_name} = key1 = TS.name_expiration_key(0)

      with_mocks [
        {Database, [],
         [
           next_key: fn ActiveNameExpiration, _key -> :none end,
           last_key: fn ActiveNameExpiration -> {:ok, key1} end,
           prev_key: fn ActiveNameExpiration, ^key1 -> :none end,
           get: fn
             ActiveName, _plain_name ->
               {:ok,
                Model.name(
                  active: true,
                  expire: 1,
                  claims: [{{0, 0}, 0}],
                  updates: [{{1, 2}, 3}],
                  transfers: [],
                  revoke: {{0, 0}, 0},
                  auction_timeout: 1
                )}

             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash ->
             %{"tx" => %{"tx" => %{"tx" => %{"pointers" => [], "account_id" => <<>>}}}}
           end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mname -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names} =
                 conn
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

        store =
          store
          |> Store.put(
            Model.InactiveName,
            Model.name(
              index: alice_name,
              owner: alice_pk,
              active: active_from,
              claims: [{{10, 0}, 1}],
              revoke: {{10, 0}, 2},
              transfers: [],
              updates: [],
              expire: expire1
            )
          )
          |> Store.put(
            Model.InactiveName,
            Model.name(
              index: bob_name,
              owner: bob_pk,
              active: active_from,
              claims: [{{10, 1}, 3}],
              revoke: {{10, 2}, 5},
              transfers: [],
              updates: [{{10, 2}, 4}],
              expire: expire2
            )
          )
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
                     "expire_height" => ^expire2
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
                     "expire_height" => ^expire1
                   },
                   "previous" => [],
                   "status" => "name"
                 }
               ] = names
      end
    end

    test "get inactive names with default limit", %{conn: conn} do
      with_mocks [
        {Database, [],
         [
           last_key: fn InactiveNameExpiration -> {:ok, TS.name_expiration_key(0)} end,
           next_key: fn InactiveNameExpiration, _exp_key -> {:ok, TS.name_expiration_key(1)} end,
           prev_key: fn InactiveNameExpiration, _exp_key -> {:ok, TS.name_expiration_key(1)} end,
           get: fn
             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found

             InactiveName, _plain_name ->
               {:ok,
                Model.name(
                  active: true,
                  expire: 1,
                  claims: [{{0, 0}, 0}],
                  updates: [],
                  transfers: [],
                  revoke: {{0, 0}, 0},
                  auction_timeout: 1
                )}

             InactiveNameExpiration, _key ->
               :ok
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mname -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names, "next" => next} =
                 conn
                 |> get("/v2/names", state: "inactive")
                 |> json_response(200)

        assert @default_limit = length(names)

        assert %{"data" => next_names, "next" => _next} =
                 conn
                 |> get(next)
                 |> json_response(200)

        assert @default_limit = length(next_names)
      end
    end

    test "get inactive names with limit=6", %{conn: conn} do
      limit = 6

      with_mocks [
        {Database, [],
         [
           last_key: fn InactiveNameExpiration -> {:ok, TS.name_expiration_key(0)} end,
           next_key: fn InactiveNameExpiration, _exp_key -> :none end,
           prev_key: fn InactiveNameExpiration, _exp_key -> {:ok, TS.name_expiration_key(0)} end,
           get: fn
             InactiveName, _plain_name ->
               {:ok,
                Model.name(
                  active: true,
                  expire: 1,
                  claims: [{{0, 0}, 0}],
                  updates: [],
                  transfers: [],
                  revoke: {{0, 0}, 0},
                  auction_timeout: 1
                )}

             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {
          Name,
          [],
          [
            pointers: fn _state, _mnme -> %{} end,
            ownership: fn _state, _mname -> %{current: nil, original: nil} end
          ]
        }
      ] do
        assert %{"data" => names} =
                 conn
                 |> get("/v2/names", state: "inactive", limit: limit)
                 |> json_response(200)

        assert ^limit = length(names)
      end
    end

    test "get inactive names with parameters by=name, direction=forward and limit=4", %{
      conn: conn
    } do
      by = "name"
      direction = "forward"
      limit = 3

      with_mocks [
        {Database, [],
         [
           first_key: fn InactiveName -> {:ok, TS.plain_name(0)} end,
           next_key: fn InactiveName, plain_name -> {:ok, "a#{plain_name}"} end,
           prev_key: fn InactiveName, _plain_name -> {:ok, "b"} end,
           get: fn
             InactiveName, _plain_name ->
               {:ok,
                Model.name(
                  active: true,
                  expire: 1,
                  claims: [{{0, 0}, 0}],
                  updates: [],
                  transfers: [],
                  revoke: {{0, 0}, 0},
                  auction_timeout: 1
                )}

             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names} =
                 conn
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

  describe "auctions" do
    test "get auctions with default limit", %{conn: conn} do
      {_exp, plain_name} = expiration_key = TS.name_expiration_key(0)

      with_mocks [
        {Database, [],
         [
           first_key: fn InactiveName -> :none end,
           last_key: fn AuctionExpiration -> {:ok, expiration_key} end,
           get: fn
             InactiveName, ^plain_name ->
               :not_found

             AuctionExpiration, {_height, ^plain_name} = key ->
               {:ok, Model.expiration(index: key)}

             AuctionBid, ^plain_name ->
               {:ok,
                Model.auction_bid(
                  index: plain_name,
                  block_index_txi: {{0, 1}, 0},
                  expire_height: 0,
                  bids: [{{2, 3}, 4}]
                )}
           end,
           next_key: fn
             AuctionExpiration, _key -> {:ok, expiration_key}
           end,
           prev_key: fn
             AuctionExpiration, _key -> {:ok, expiration_key}
           end,
           exists?: fn _tab, _key -> true end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Db, [],
         [
           proto_vsn: fn _height -> 1 end
         ]}
      ] do
        assert %{"data" => auction_bids, "next" => next} =
                 conn
                 |> get("/v2/names/auctions")
                 |> json_response(200)

        assert @default_limit = length(auction_bids)

        assert %{"data" => auction_bids2} =
                 conn
                 |> get(next)
                 |> json_response(200)

        assert @default_limit = length(auction_bids2)
      end
    end

    test "get auctions with limit=2", %{conn: conn} do
      limit = 2
      {_exp, plain_name} = expiration_key = TS.name_expiration_key(0)

      with_mocks [
        {Database, [],
         [
           get: fn
             InactiveName, ^plain_name ->
               :not_found

             AuctionBid, ^plain_name ->
               {:ok,
                Model.auction_bid(
                  index: plain_name,
                  block_index_txi: {{0, 1}, 3},
                  expire_height: 0,
                  bids: [{{2, 3}, 4}]
                )}
           end,
           last_key: fn AuctionExpiration -> {:ok, expiration_key} end,
           next_key: fn
             AuctionBid, _key ->
               {:ok, {plain_name, {0, 1}, 0, :owner_pk, [{{2, 3}, 4}]}}

             AuctionExpiration, _key ->
               {:ok, expiration_key}
           end,
           prev_key: fn
             AuctionBid, _key ->
               {:ok, {plain_name, {0, 1}, 0, :owner_pk, [{{2, 3}, 4}]}}

             AuctionExpiration, _key ->
               {:ok, expiration_key}
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Db, [],
         [
           proto_vsn: fn _height -> 1 end
         ]}
      ] do
        assert %{"data" => auctions} =
                 conn
                 |> get("/v2/names/auctions", limit: limit)
                 |> json_response(200)

        assert ^limit = length(auctions)
      end
    end

    test "get auctions with parameters by=expiration, direction=forward and limit=3", %{
      conn: conn
    } do
      by = "expiration"
      direction = "forward"
      limit = 3
      {_exp, plain_name} = expiration_key = TS.name_expiration_key(0)

      with_mocks [
        {Database, [],
         [
           get: fn
             InactiveName, ^plain_name ->
               :not_found

             AuctionBid, ^plain_name ->
               {:ok,
                Model.auction_bid(
                  index: plain_name,
                  block_index_txi: {{0, 1}, 0},
                  expire_height: 30,
                  bids: [{{2, 3}, 4}]
                )}
           end,
           first_key: fn AuctionExpiration -> {:ok, expiration_key} end,
           next_key: fn AuctionExpiration, _key -> {:ok, expiration_key} end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Db, [],
         [
           proto_vsn: fn _height -> 1 end
         ]}
      ] do
        assert %{"data" => auctions} =
                 conn
                 |> get("/v2/names/auctions", by: by, direction: direction, limit: limit)
                 |> json_response(200)

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
      conn: conn
    } do
      with_mocks [
        {Database, [],
         [
           last_key: fn
             ActiveNameExpiration -> {:ok, TS.name_expiration_key(0)}
             InactiveNameExpiration -> :none
           end,
           prev_key: fn ActiveNameExpiration, {exp, plain_name} ->
             {:ok, {exp - 1, "a#{plain_name}"}}
           end,
           get: fn
             ActiveName, _plain_name ->
               {:ok,
                Model.name(
                  active: true,
                  expire: 1,
                  claims: [{{0, 0}, 0}],
                  updates: [],
                  transfers: [],
                  revoke: {{0, 0}, 0},
                  auction_timeout: 1
                )}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names, "next" => _next} =
                 conn
                 |> get("/names")
                 |> json_response(200)

        assert @default_limit = length(names)
      end
    end

    test "get active and inactive names, except those in auction, with limit=2", %{conn: conn} do
      limit = 2

      with_mocks [
        {Database, [],
         [
           last_key: fn
             ActiveNameExpiration -> {:ok, TS.name_expiration_key(0)}
             InactiveNameExpiration -> :none
           end,
           prev_key: fn
             ActiveNameExpiration, {exp, plain_name} ->
               {:ok, {exp - 1, "a#{plain_name}"}}
           end,
           get: fn
             AuctionBid, _key ->
               :not_found

             ActiveName, _plain_name ->
               {:ok,
                Model.name(
                  active: true,
                  expire: 1,
                  claims: [{{0, 0}, 0}],
                  updates: [],
                  transfers: [],
                  revoke: {{0, 0}, 0},
                  auction_timeout: 1
                )}
           end,
           last_key: fn InactiveNameExpiration, nil -> nil end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mname -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names} =
                 conn
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

      inactive_name =
        Model.name(
          index: first_name,
          active: false,
          expire: 3,
          claims: [{{2, 0}, 0}],
          updates: [],
          transfers: [],
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

      with_mocks [
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]}
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
         %{conn: conn} do
      limit = 4
      by = "name"
      direction = "forward"
      first_key = TS.plain_name(0)

      with_mocks [
        {Database, [],
         [
           first_key: fn
             InactiveName -> :none
             ActiveName -> {:ok, first_key}
           end,
           next_key: fn ActiveName, key -> {:ok, "a#{key}"} end,
           get: fn
             ActiveName, _plain_name ->
               {:ok,
                Model.name(
                  active: Enum.random(1000..9999),
                  expire: 1,
                  claims: [{{0, 0}, 0}],
                  updates: [],
                  transfers: [],
                  revoke: {{0, 0}, 0},
                  auction_timeout: 1
                )}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names, "next" => _next} =
                 conn
                 |> get("/names?by=#{by}&direction=#{direction}&limit=#{limit}")
                 |> json_response(200)

        plain_names = Enum.map(names, & &1["name"])
        assert plain_names == Enum.sort(plain_names)
        assert ^limit = length(names)
      end
    end

    test "get active names with parameters by=activation, direction=forward and limit=9",
         %{conn: conn, height_name: height_name} do
      limit = 9
      by = "activation"
      direction = "forward"

      with_mocks [
        {Database, [],
         [
           first_key: fn ActiveNameActivation -> {:ok, {100, height_name[100]}} end,
           next_key: fn
             ActiveNameActivation, {height, _name} ->
               {:ok, {height + 1, height_name[height + 1]}}
           end,
           get: fn
             ActiveName, plain_name ->
               active_from =
                 Enum.find_value(height_name, fn {height, name} ->
                   if name == plain_name, do: height
                 end)

               {:ok,
                Model.name(
                  active: active_from,
                  expire: active_from + 10,
                  claims: [{{active_from, 0}, 0}]
                )}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _state, _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _state, _mnme -> %{} end,
           ownership: fn _state, _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names, "next" => _next} =
                 conn
                 |> get("/names", state: "active", by: by, direction: direction, limit: limit)
                 |> json_response(200)

        heights = Enum.map(names, & &1["info"]["active_from"])
        assert heights == Enum.sort(heights)
        assert ^limit = length(names)
      end
    end

    test "get inactive names for given account/owner", %{conn: conn} do
      owner_id = "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
      owner_pk = Validate.id!(owner_id)
      other_pk = :crypto.strong_rand_bytes(32)
      limit = 2
      first_name = TS.plain_name(4)
      not_owned_name = "o2#{first_name}"
      second_name = "o1#{first_name}"

      m_name =
        Model.name(
          index: first_name,
          active: false,
          expire: 3,
          claims: [{{2, 0}, 0}],
          updates: [],
          transfers: [],
          revoke: nil,
          owner: owner_pk,
          auction_timeout: 1
        )

      Database.dirty_write(InactiveName, m_name)
      Database.dirty_write(InactiveName, Model.name(m_name, index: second_name))

      Database.dirty_write(
        InactiveName,
        Model.name(m_name, index: not_owned_name, owner: other_pk)
      )

      Database.dirty_write(InactiveNameOwner, Model.owner(index: {owner_pk, first_name}))
      Database.dirty_write(InactiveNameOwner, Model.owner(index: {owner_pk, second_name}))
      Database.dirty_write(InactiveNameOwner, Model.owner(index: {other_pk, not_owned_name}))

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
         ]}
      ] do
        assert %{"data" => owned_names} =
                 conn
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

      inactive_name =
        Model.name(
          index: first_name,
          active: false,
          expire: 3,
          claims: [{{2, 0}, 0}],
          updates: [],
          transfers: [],
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
         ]}
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
              claims: [{{1, 1}, 1}],
              updates: [{{1, 1}, 2}],
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

    test "get inactive name in auction", %{conn: conn, store: store} do
      name = "alice.chain"

      with_blockchain %{alice: 1_000},
        mb: [
          tx: name_tx(:name_claim_tx, :alice, name)
        ] do
        %{txs: [tx]} = blocks[:mb]
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
              claims: [{{10, 1}, claim_txi}],
              expire: expire
            )
          )
          |> Store.put(
            Model.AuctionBid,
            Model.auction_bid(index: name, expire_height: bid_expire, bids: [{{1, 1}, bid_txi}])
          )
          |> Store.put(Model.AuctionOwner, Model.owner(index: {alice_pk, name}))
          |> Store.put(Model.AuctionExpiration, Model.expiration(index: {bid_expire, name}))
          |> Store.put(
            Model.Tx,
            Model.tx(index: bid_txi, id: :aetx_sign.hash(tx), block_index: {1, 1})
          )

        assert %{
                 "name" => ^name,
                 "active" => false,
                 "auction" => %{"auction_end" => ^bid_expire, "bids" => [^bid_txi]},
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
           ownership: fn _state, _name -> %{original: <<>>, current: <<>>} end
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
          |> Store.put(Model.ActiveName, Model.name(index: name, updates: [{{0, 0}, 2}]))

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
      owner_id = Validate.id!(id)

      with_mocks [
        {Name, [], [owned_by: fn _state, ^owner_id, true -> %{names: [], top_bids: []} end]}
      ] do
        assert %{"active" => [], "top_bid" => []} =
                 conn |> get("/names/owned_by/#{id}") |> json_response(200)
      end
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
end
