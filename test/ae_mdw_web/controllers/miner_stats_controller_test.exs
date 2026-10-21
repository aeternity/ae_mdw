defmodule AeMdwWeb.MinerStatsControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.State
  alias AeMdw.MinerStats.Fold
  alias AeMdw.MinerStatsFixtures
  alias AeMdw.Node

  @m1 <<1::256>>
  @m2 <<2::256>>
  @m3 <<3::256>>
  @b1 <<11::256>>
  @b2 <<12::256>>
  @b3 <<13::256>>

  setup %{conn: conn, store: store} do
    MinerStatsFixtures.fold_history(State.new(store))

    {:ok, conn: with_store(conn, store)}
  end

  describe "GET /v3/stats/mining" do
    test "it returns the totals and how far the stats are folded", %{conn: conn} do
      assert %{
               "bucket_size" => 20,
               "mdw_height" => 75,
               "stats_height" => 60,
               "last_bucket" => 3,
               "blocks" => 6,
               "txs" => 6,
               "rewards" => 134,
               "fees" => 45,
               "miners" => 3,
               "beneficiaries" => 3
             } = conn |> get("/v3/stats/mining") |> json_response(200)
    end

    test "it returns zeros when nothing was folded yet", %{conn: conn} do
      store = AeMdw.Sync.MemStoreCreator.create(AeMdw.Db.NullStore.new())

      assert %{
               "mdw_height" => 0,
               "stats_height" => 0,
               "last_bucket" => nil,
               "blocks" => 0,
               "miners" => 0
             } =
               conn |> with_store(store) |> get("/v3/stats/mining") |> json_response(200)
    end
  end

  describe "GET /v3/miners" do
    test "it lists the miners by blocks mined", %{conn: conn} do
      m1 = id(@m1)
      m2 = id(@m2)
      m3 = id(@m3)

      assert %{"prev" => nil, "data" => [first, %{"id" => ^m3}, %{"id" => ^m2}], "next" => nil} =
               conn |> get("/v3/miners") |> json_response(200)

      assert %{
               "id" => ^m1,
               "role" => "miner",
               "first_height" => 20,
               "first_time" => 1_000,
               "last_height" => 60,
               "last_time" => 6_000,
               "blocks" => 4,
               "txs" => 5,
               "rewards" => nil,
               "fees" => 35
             } = first
    end

    test "it lists the beneficiaries by rewards", %{conn: conn} do
      [b1, b2, b3] = Enum.map([@b1, @b2, @b3], &id/1)

      assert %{"data" => [%{"id" => ^b2, "rewards" => 79}, %{"id" => ^b1}, %{"id" => ^b3}]} =
               conn
               |> get("/v3/miners", role: "beneficiary", by: "rewards")
               |> json_response(200)
    end

    test "it lists the miners by when they first mined", %{conn: conn} do
      [m1, m2, m3] = Enum.map([@m1, @m2, @m3], &id/1)

      assert %{"data" => [%{"id" => ^m1}, %{"id" => ^m2}, %{"id" => ^m3}]} =
               conn
               |> get("/v3/miners", by: "first_active", direction: "forward")
               |> json_response(200)
    end

    test "it paginates in both directions", %{conn: conn} do
      [m1, m2, m3] = Enum.map([@m1, @m2, @m3], &id/1)

      assert page1 =
               %{"prev" => nil, "data" => [%{"id" => ^m1}, %{"id" => ^m3}], "next" => next} =
               conn |> get("/v3/miners", limit: 2) |> json_response(200)

      assert %{"prev" => prev, "data" => [%{"id" => ^m2}], "next" => nil} =
               conn |> get(next) |> json_response(200)

      assert ^page1 = conn |> get(prev) |> json_response(200)
    end

    test "it returns an error for invalid params", %{conn: conn} do
      assert %{"error" => "invalid query: role=pool"} =
               conn |> get("/v3/miners", role: "pool") |> json_response(400)

      assert %{"error" => "invalid query: by=speed"} =
               conn |> get("/v3/miners", by: "speed") |> json_response(400)

      assert %{"error" => "invalid query: by=rewards"} =
               conn |> get("/v3/miners", by: "rewards") |> json_response(400)

      assert %{"error" => "invalid query: foo=bar"} =
               conn |> get("/v3/miners", foo: "bar") |> json_response(400)

      assert %{"error" => "invalid cursor: nope"} =
               conn |> get("/v3/miners", cursor: "nope") |> json_response(400)
    end
  end

  describe "GET /v3/miners/:id" do
    test "it returns the miner or the beneficiary", %{conn: conn} do
      b1 = id(@b1)

      assert %{"id" => _id, "role" => "miner", "blocks" => 4} =
               conn |> get("/v3/miners/#{id(@m1)}") |> json_response(200)

      assert %{"id" => ^b1, "role" => "beneficiary", "blocks" => 4, "rewards" => 55} =
               conn |> get("/v3/miners/#{b1}", role: "beneficiary") |> json_response(200)
    end

    test "it finds the role of the account when it's not given", %{conn: conn} do
      [m3, b2] = Enum.map([@m3, @b2], &id/1)

      assert %{"id" => ^m3, "role" => "miner"} =
               conn |> get("/v3/miners/#{m3}") |> json_response(200)

      assert %{"id" => ^b2, "role" => "beneficiary", "rewards" => 79} =
               conn |> get("/v3/miners/#{b2}") |> json_response(200)
    end

    test "it uses the miner when the account is both, unless the role is given", %{
      conn: conn,
      store: store
    } do
      Fold.fold(State.new(store), %{
        height: 61,
        time: 7_000,
        miner: @b1,
        beneficiary: @b1,
        difficulty: 100,
        micro_blocks: 0,
        txs: 0,
        fees: 0,
        rewards: %{}
      })

      b1 = id(@b1)

      assert %{"id" => ^b1, "role" => "miner", "blocks" => 1} =
               conn |> get("/v3/miners/#{b1}") |> json_response(200)

      assert %{"id" => ^b1, "role" => "beneficiary", "blocks" => 5} =
               conn |> get("/v3/miners/#{b1}", role: "beneficiary") |> json_response(200)
    end

    test "it returns an error when it's not found or invalid", %{conn: conn} do
      unknown = id(<<99::256>>)
      error = "not found: #{unknown}"

      assert %{"error" => ^error} = conn |> get("/v3/miners/#{unknown}") |> json_response(404)

      assert %{"error" => _invalid} = conn |> get("/v3/miners/not-an-id") |> json_response(400)
    end
  end

  describe "GET /v3/miners/:id/links" do
    test "it returns the miner keys of a beneficiary", %{conn: conn} do
      [m1, m2] = Enum.map([@m1, @m2], &id/1)

      assert %{
               "data" => [
                 %{"id" => ^m2, "blocks" => 1, "first_height" => 21, "last_height" => 21},
                 %{"id" => ^m1, "blocks" => 3, "first_height" => 20, "last_height" => 60}
               ]
             } = conn |> get("/v3/miners/#{id(@b1)}/links") |> json_response(200)

      assert %{"data" => []} = conn |> get("/v3/miners/#{id(@m1)}/links") |> json_response(200)
    end

    test "it paginates", %{conn: conn} do
      [m1, m2] = Enum.map([@m1, @m2], &id/1)

      assert %{"data" => [%{"id" => ^m2, "blocks" => 1}], "next" => next} =
               conn |> get("/v3/miners/#{id(@b1)}/links", limit: 1) |> json_response(200)

      assert %{"data" => [%{"id" => ^m1, "blocks" => 3}], "next" => nil} =
               conn |> get(next) |> json_response(200)
    end

    test "it doesn't take a role", %{conn: conn} do
      assert %{"error" => "invalid query: role=beneficiary"} =
               conn
               |> get("/v3/miners/#{id(@b1)}/links", role: "beneficiary")
               |> json_response(400)
    end
  end

  describe "GET /v3/miners/:id/series" do
    test "it returns the buckets where the miner mined with the totals up to there", %{
      conn: conn
    } do
      assert %{"prev" => nil, "data" => [bucket3, bucket2, bucket1], "next" => nil} =
               conn |> get("/v3/miners/#{id(@m1)}/series") |> json_response(200)

      assert %{
               "bucket" => 3,
               "interval" => 1,
               "start_height" => 60,
               "end_height" => 79,
               "start_time" => 6_000,
               "blocks" => 1,
               "blocks_total" => 4,
               "rewards" => nil
             } = bucket3

      assert %{"bucket" => 2, "blocks" => 1, "txs" => 2, "fees" => 5, "txs_total" => 5} = bucket2

      assert %{
               "bucket" => 1,
               "start_height" => 20,
               "end_height" => 39,
               "start_time" => 1_000,
               "end_time" => 3_000,
               "blocks" => 2,
               "txs" => 3,
               "fees" => 30,
               "blocks_total" => 2,
               "txs_total" => 3
             } = bucket1
    end

    test "it finds the role of the account when it's not given", %{conn: conn} do
      assert %{"data" => [%{"bucket" => 2, "rewards" => 9}, %{"bucket" => 1, "rewards" => 70}]} =
               conn |> get("/v3/miners/#{id(@b2)}/series") |> json_response(200)
    end

    test "it returns the rewards of a beneficiary, also in buckets it didn't mine", %{conn: conn} do
      assert %{"data" => [bucket2, bucket1]} =
               conn
               |> get("/v3/miners/#{id(@b2)}/series", role: "beneficiary")
               |> json_response(200)

      assert %{"bucket" => 2, "blocks" => 0, "rewards" => 9, "rewards_total" => 79} = bucket2

      assert %{"bucket" => 1, "blocks" => 1, "rewards" => 70, "rewards_total" => 70} = bucket1
    end

    test "it returns the indexed rows of an interval", %{conn: conn} do
      assert %{"prev" => nil, "data" => [day], "next" => nil} =
               conn
               |> get("/v3/miners/#{id(@m1)}/series", interval: 24)
               |> json_response(200)

      assert %{
               "bucket" => 0,
               "interval" => 24,
               "start_height" => 0,
               "end_height" => 479,
               "start_time" => 1_000,
               "end_time" => 6_000,
               "blocks" => 4,
               "txs" => 5,
               "fees" => 35,
               "blocks_total" => 4
             } = day

      assert %{"data" => [%{"interval" => 8760, "end_height" => 175_199, "blocks" => 4}]} =
               conn
               |> get("/v3/miners/#{id(@m1)}/series", interval: 8760)
               |> json_response(200)
    end

    test "it only returns the buckets of the scope", %{conn: conn} do
      assert %{"data" => [%{"bucket" => 2}, %{"bucket" => 3}]} =
               conn
               |> get("/v3/miners/#{id(@m1)}/series", scope: "gen:40-79")
               |> json_response(200)
    end

    test "it paginates", %{conn: conn} do
      assert page1 =
               %{"prev" => nil, "data" => [%{"bucket" => 3}], "next" => next} =
               conn |> get("/v3/miners/#{id(@m1)}/series", limit: 1) |> json_response(200)

      assert %{"prev" => prev, "data" => [%{"bucket" => 2}], "next" => next2} =
               conn |> get(next) |> json_response(200)

      assert %{"data" => [%{"bucket" => 1}], "next" => nil} =
               conn |> get(next2) |> json_response(200)

      assert ^page1 = conn |> get(prev) |> json_response(200)
    end

    test "it returns an error for invalid params", %{conn: conn} do
      path = "/v3/miners/#{id(@m1)}/series"

      assert %{"error" => "invalid query: interval=0"} =
               conn |> get(path, interval: 0) |> json_response(400)

      assert %{"error" => "invalid query: interval=x"} =
               conn |> get(path, interval: "x") |> json_response(400)

      assert %{"error" => "invalid query: interval=2"} =
               conn |> get(path, interval: 2) |> json_response(400)

      assert %{"error" => "invalid query: interval_by=day"} =
               conn |> get(path, interval_by: "day") |> json_response(400)

      assert %{"error" => "invalid query: foo=bar"} =
               conn |> get(path, foo: "bar") |> json_response(400)

      assert %{"error" => "invalid cursor: x"} =
               conn |> get(path, cursor: "x") |> json_response(400)
    end
  end

  describe "GET /v3/stats/mining/series" do
    test "it returns the network buckets", %{conn: conn} do
      assert %{"prev" => nil, "data" => [bucket3, bucket2, bucket1], "next" => nil} =
               conn |> get("/v3/stats/mining/series") |> json_response(200)

      assert [3, 2, 1] = Enum.map([bucket3, bucket2, bucket1], & &1["bucket"])

      hashrate = Node.difficulty_to_hashrate(133)

      assert %{
               "interval" => 1,
               "start_height" => 20,
               "end_height" => 22,
               "start_time" => 1_000,
               "end_time" => 3_000,
               "blocks" => 3,
               "micro_blocks" => 3,
               "txs" => 4,
               "rewards" => 125,
               "fees" => 40,
               "avg_block_time" => 1_000,
               "avg_difficulty" => 133,
               "hashrate" => ^hashrate,
               "active_miners" => 2,
               "active_beneficiaries" => 2,
               "new_miners" => 2,
               "new_beneficiaries" => 2,
               "blocks_total" => 3,
               "txs_total" => 4,
               "rewards_total" => 125,
               "fees_total" => 40,
               "miners_total" => 2,
               "beneficiaries_total" => 2
             } = bucket1

      assert %{"blocks" => 1, "avg_block_time" => nil, "miners_total" => 3} = bucket3
    end

    test "it returns the indexed rows of an interval counting the miners once", %{conn: conn} do
      assert %{"prev" => nil, "data" => [day], "next" => nil} =
               conn |> get("/v3/stats/mining/series", interval: 24) |> json_response(200)

      assert %{
               "bucket" => 0,
               "interval" => 24,
               "start_height" => 20,
               "end_height" => 60,
               "start_time" => 1_000,
               "end_time" => 6_000,
               "blocks" => 6,
               "txs" => 6,
               "rewards" => 134,
               "active_miners" => 3,
               "active_beneficiaries" => 3,
               "new_miners" => 3,
               "blocks_total" => 6,
               "miners_total" => 3
             } = day

      for interval <- [168, 720, 8760] do
        assert %{"data" => [%{"blocks" => 6, "active_miners" => 3}]} =
                 conn
                 |> get("/v3/stats/mining/series", interval: interval)
                 |> json_response(200)
      end
    end

    test "it only returns the buckets of the scope in the scope order", %{conn: conn} do
      assert %{"data" => [%{"bucket" => 1}, %{"bucket" => 2}]} =
               conn
               |> get("/v3/stats/mining/series", scope: "gen:20-59")
               |> json_response(200)
    end

    test "it doesn't accept miner params", %{conn: conn} do
      assert %{"error" => "invalid query: role=miner"} =
               conn |> get("/v3/stats/mining/series", role: "miner") |> json_response(400)
    end
  end

  describe "GET /v3/stats/mining/buckets/:bucket" do
    test "it returns the network bucket", %{conn: conn} do
      assert %{"bucket" => 1, "blocks" => 3, "active_miners" => 2} =
               conn |> get("/v3/stats/mining/buckets/1") |> json_response(200)
    end

    test "it returns an error when it's not found or invalid", %{conn: conn} do
      assert %{"error" => "not found: 99"} =
               conn |> get("/v3/stats/mining/buckets/99") |> json_response(404)

      assert %{"error" => "invalid query: bucket=x"} =
               conn |> get("/v3/stats/mining/buckets/x") |> json_response(400)
    end
  end

  describe "GET /v3/stats/mining/buckets/:bucket/miners" do
    test "it returns the miners that mined in the bucket", %{conn: conn} do
      [m1, m2] = Enum.map([@m1, @m2], &id/1)

      assert %{
               "data" => [
                 %{"id" => ^m2, "blocks" => 1, "txs" => 1, "blocks_total" => 1},
                 %{"id" => ^m1, "blocks" => 2, "txs" => 3, "blocks_total" => 2}
               ]
             } = conn |> get("/v3/stats/mining/buckets/1/miners") |> json_response(200)
    end

    test "it doesn't return the beneficiaries that were only paid", %{conn: conn} do
      [b1, b3] = Enum.map([@b1, @b3], &id/1)

      assert %{"data" => [%{"id" => ^b3, "blocks" => 1}, %{"id" => ^b1, "blocks" => 1}]} =
               conn
               |> get("/v3/stats/mining/buckets/2/miners", role: "beneficiary")
               |> json_response(200)
    end

    test "it paginates", %{conn: conn} do
      [m1, m2] = Enum.map([@m1, @m2], &id/1)

      assert %{"data" => [%{"id" => ^m2}], "next" => next} =
               conn |> get("/v3/stats/mining/buckets/1/miners", limit: 1) |> json_response(200)

      assert %{"data" => [%{"id" => ^m1}], "next" => nil} =
               conn |> get(next) |> json_response(200)
    end
  end

  defp id(pk), do: :aeapi.format_account_pubkey(pk)
end
