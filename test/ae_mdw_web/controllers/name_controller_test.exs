defmodule AeMdwWeb.NameControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Model.ActiveName
  alias AeMdw.Db.Model.ActiveNameExpiration
  alias AeMdw.Db.Model.AuctionBid
  alias AeMdw.Db.Model.AuctionExpiration
  alias AeMdw.Db.Model.InactiveName
  alias AeMdw.Db.Model.InactiveNameExpiration
  alias AeMdw.Db.Model.Tx
  alias AeMdw.Db.Name
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Database
  alias AeMdw.Validate
  alias AeMdw.TestSamples, as: TS
  alias AeMdw.Txs

  import Mock

  require Model

  @default_limit 10

  describe "active_names" do
    test "get active names with default limit", %{conn: conn} do
      with_mocks [
        {Database, [],
         [
           last_key: fn ActiveNameExpiration -> {:ok, TS.name_expiration_key(0)} end,
           next_key: fn ActiveNameExpiration, _exp_key -> :none end,
           prev_key: fn ActiveNameExpiration, _exp_key -> {:ok, TS.name_expiration_key(1)} end,
           get: fn
             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found

             ActiveNameExpiration, _key ->
               :not_found
           end,
           fetch: fn
             AuctionBid, _plain_name ->
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
           fetch!: fn
             ActiveName, _plain_name ->
               Model.name(
                 active: true,
                 expire: 1,
                 claims: [{{0, 0}, 0}],
                 updates: [],
                 transfers: [],
                 revoke: {{0, 0}, 0},
                 auction_timeout: 1
               )
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _mnme -> %{} end,
           ownership: fn _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names, "next" => next} =
                 conn
                 |> get("/v2/names", state: "active")
                 |> json_response(200)

        assert @default_limit = length(names)

        assert %{"data" => names_next, "next" => _next} =
                 conn
                 |> get(next)
                 |> json_response(200)

        assert @default_limit = length(names_next)
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
           fetch!: fn ActiveName, _plain_name ->
             Model.name(
               active: true,
               expire: 1,
               claims: [{{0, 0}, 0}],
               updates: [],
               transfers: [],
               revoke: {{0, 0}, 0},
               auction_timeout: 1
             )
           end,
           fetch: fn
             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _mnme -> %{} end,
           ownership: fn _mname -> %{current: nil, original: nil} end
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
           fetch!: fn ActiveName, _plain_name ->
             Model.name(
               active: true,
               expire: 1,
               claims: [{{0, 0}, 0}],
               updates: [{{1, 2}, 3}],
               transfers: [],
               revoke: {{0, 0}, 0},
               auction_timeout: 1
             )
           end,
           fetch: fn
             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _hash ->
             %{"tx" => %{"tx" => %{"tx" => %{"pointers" => [], "account_id" => <<>>}}}}
           end
         ]},
        {Name, [],
         [
           pointers: fn _mnme -> %{} end,
           ownership: fn _mname -> %{current: nil, original: nil} end
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
    test "get inactive names with default limit", %{conn: conn} do
      with_mocks [
        {Database, [],
         [
           last_key: fn InactiveNameExpiration -> {:ok, TS.name_expiration_key(0)} end,
           next_key: fn InactiveNameExpiration, _exp_key -> {:ok, TS.name_expiration_key(1)} end,
           prev_key: fn InactiveNameExpiration, _exp_key -> {:ok, TS.name_expiration_key(1)} end,
           fetch: fn
             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found
           end,
           fetch!: fn InactiveName, _plain_name ->
             Model.name(
               active: true,
               expire: 1,
               claims: [{{0, 0}, 0}],
               updates: [],
               transfers: [],
               revoke: {{0, 0}, 0},
               auction_timeout: 1
             )
           end,
           get: fn
             InactiveNameExpiration, _key -> :ok
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _mnme -> %{} end,
           ownership: fn _mname -> %{current: nil, original: nil} end
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
           fetch!: fn InactiveName, _plain_name ->
             Model.name(
               active: true,
               expire: 1,
               claims: [{{0, 0}, 0}],
               updates: [],
               transfers: [],
               revoke: {{0, 0}, 0},
               auction_timeout: 1
             )
           end,
           fetch: fn
             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {
          Name,
          [],
          [
            pointers: fn _mnme -> %{} end,
            ownership: fn _mname -> %{current: nil, original: nil} end
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
           fetch!: fn InactiveName, _plain_name ->
             Model.name(
               active: true,
               expire: 1,
               claims: [{{0, 0}, 0}],
               updates: [],
               transfers: [],
               revoke: {{0, 0}, 0},
               auction_timeout: 1
             )
           end,
           fetch: fn
             Tx, _key ->
               {:ok, Model.tx(index: 0, id: 0, block_index: {0, 0}, time: 0)}

             AuctionBid, _key ->
               :not_found
           end
         ]},
        {Txs, [],
         [
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _mnme -> %{} end,
           ownership: fn _mname -> %{current: nil, original: nil} end
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
           end,
           fetch: fn
             AuctionBid, ^plain_name ->
               {:ok,
                Model.auction_bid(
                  index: plain_name,
                  block_index_txi: {{0, 1}, 0},
                  expire_height: 0,
                  bids: [{{2, 3}, 4}]
                )}

             InactiveName, ^plain_name ->
               :not_found
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
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {DbUtil, [],
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
           fetch: fn
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
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {DbUtil, [],
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
           fetch: fn
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
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {DbUtil, [],
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
           fetch!: fn _tab, _plain_name ->
             Model.name(
               active: true,
               expire: 1,
               claims: [{{0, 0}, 0}],
               updates: [],
               transfers: [],
               revoke: {{0, 0}, 0},
               auction_timeout: 1
             )
           end,
           fetch: fn AuctionBid, _key -> :not_found end
         ]},
        {Txs, [],
         [
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _mnme -> %{} end,
           ownership: fn _mname -> %{current: nil, original: nil} end
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
           fetch!: fn ActiveName, _plain_name ->
             Model.name(
               active: true,
               expire: 1,
               claims: [{{0, 0}, 0}],
               updates: [],
               transfers: [],
               revoke: {{0, 0}, 0},
               auction_timeout: 1
             )
           end,
           fetch: fn AuctionBid, _key -> :not_found end,
           last_key: fn InactiveNameExpiration, nil -> nil end
         ]},
        {Txs, [],
         [
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _mnme -> %{} end,
           ownership: fn _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names} =
                 conn
                 |> get("/v2/names", limit: limit)
                 |> json_response(200)

        assert ^limit = length(names)
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
           fetch!: fn ActiveName, _plain_name ->
             Model.name(
               active: true,
               expire: 1,
               claims: [{{0, 0}, 0}],
               updates: [],
               transfers: [],
               revoke: {{0, 0}, 0},
               auction_timeout: 1
             )
           end,
           fetch: fn AuctionBid, _key -> :not_found end
         ]},
        {Txs, [],
         [
           fetch!: fn _hash -> %{"tx" => %{"account_id" => <<>>}} end
         ]},
        {Name, [],
         [
           pointers: fn _mnme -> %{} end,
           ownership: fn _mname -> %{current: nil, original: nil} end
         ]}
      ] do
        assert %{"data" => names, "next" => _next} =
                 conn
                 |> get("/names?by=#{by}&direction=#{direction}&limit=#{limit}")
                 |> json_response(200)

        assert ^limit = length(names)
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
    test "get name info by name", %{conn: conn} do
      name = "wwwbeaconoidcom.chain"
      own_original = <<>>
      own_current = <<>>

      with_mocks [
        {Name, [],
         [
           locate: fn ^name ->
             {Model.name(index: name, active: true, expire: 0), Model.ActiveName}
           end,
           locate_bid: fn ^name -> nil end,
           pointers: fn _name_model -> %{} end,
           ownership: fn _name_model -> %{original: own_original, current: own_current} end
         ]}
      ] do
        assert %{
                 "name" => ^name,
                 "active" => true,
                 "info" => %{
                   "ownership" => %{"current" => ^own_current, "original" => ^own_original}
                 }
               } = conn |> get("/v2/names/#{name}") |> json_response(200)
      end
    end

    test "get name info by encoded hash ", %{conn: conn} do
      hash = "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj"
      hash_id = Validate.id!(hash)
      name = "some-name.chain"

      with_mocks [
        {Name, [],
         [
           plain_name: fn ^hash_id -> {:ok, name} end,
           locate: fn ^name ->
             {Model.name(index: name, active: true, expire: 0), Model.ActiveName}
           end,
           locate_bid: fn ^name -> nil end,
           pointers: fn _name_model -> %{} end,
           ownership: fn _name -> %{original: <<>>, current: <<>>} end
         ]}
      ] do
        assert %{"active" => true, "name" => ^name} =
                 conn |> get("/v2/names/#{hash}") |> json_response(200)
      end
    end

    test "renders error when no such name is present", %{conn: conn} do
      name = "no--such--name--in--the--chain.chain"
      error = "not found: #{name}"

      with_mocks [{Name, [], [locate: fn ^name -> nil end]}] do
        assert %{"error" => ^error} = conn |> get("/v2/names/#{name}") |> json_response(404)
      end
    end
  end

  describe "pointers" do
    test "get pointers for valid given name", %{conn: conn} do
      id = "wwwbeaconoidcom.chain"
      some_reply = %{"foo" => "bar"}

      with_mocks [
        {Name, [],
         [
           locate: fn ^id ->
             {Model.name(index: id, active: true, expire: 0), Model.ActiveName}
           end,
           pointers: fn _name_model -> some_reply end
         ]}
      ] do
        assert ^some_reply = conn |> get("/v2/names/#{id}/pointers") |> json_response(200)
      end
    end

    test "renders error when the name is missing", %{conn: conn} do
      id = "no--such--name--in--the--chain.chain"
      error = "not found: #{id}"

      with_mocks [{Name, [], [locate: fn ^id -> nil end]}] do
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
        {Name, [], [pointees: fn ^name_id -> {active_pointees, inactive_pointees} end]}
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
        {Name, [], [owned_by: fn ^owner_id, true -> %{names: [], top_bids: []} end]}
      ] do
        assert %{"active" => [], "top_bid" => []} =
                 conn |> get("/names/owned_by/#{id}") |> json_response(200)
      end
    end

    test "get inactive names for given account/owner", %{conn: conn} do
      id = "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
      owner_id = Validate.id!(id)

      with_mocks [
        {Name, [], [owned_by: fn ^owner_id, false -> %{names: []} end]}
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
