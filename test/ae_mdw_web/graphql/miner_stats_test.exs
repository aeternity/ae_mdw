defmodule AeMdwWeb.GraphQL.MinerStatsTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.State
  alias AeMdw.MinerStatsFixtures

  @schema AeMdwWeb.GraphQL.Schema

  setup %{store: store} do
    state = MinerStatsFixtures.fold_history(State.new(store))

    :ets.delete_all_objects(:miner_stats_sorted)

    {:ok, state: state, ids: ids()}
  end

  describe "miningSummary" do
    test "it returns the totals", %{state: state} do
      assert {:ok, %{data: %{"miningSummary" => summary}} = res} =
               run(
                 state,
                 "{ miningSummary { bucketSize syncedHeight lastBucket blocks rewards miners } }"
               )

      refute res[:errors]

      assert %{"bucketSize" => 20, "syncedHeight" => 60, "lastBucket" => 3, "blocks" => 6} =
               summary

      assert %{"rewards" => "134", "miners" => 3} = summary
    end
  end

  describe "miners" do
    test "it lists the miners sorted by blocks mined", %{state: state, ids: ids} do
      assert {:ok, %{data: %{"miners" => %{"data" => [first, second, third]}}} = res} =
               run(
                 state,
                 "{ miners { data { id role blocks txs rewards firstHeight lastInfo } } }"
               )

      refute res[:errors]

      assert %{"id" => id1, "role" => "miner", "blocks" => 4, "txs" => 5, "rewards" => nil} =
               first

      assert id1 == ids.m1
      assert %{"id" => id3} = second
      assert id3 == ids.m3
      assert %{"id" => id2} = third
      assert id2 == ids.m2
      assert %{"firstHeight" => 20, "lastInfo" => 2} = first
    end

    test "it lists the beneficiaries by rewards and paginates", %{state: state, ids: ids} do
      query = fn args ->
        "{ miners(role: BENEFICIARY, orderBy: REWARDS, #{args}) { nextCursor prevCursor data { id rewards } } }"
      end

      assert {:ok, %{data: %{"miners" => %{"data" => [first], "nextCursor" => next}}}} =
               run(state, query.("limit: 1"))

      assert %{"id" => id2, "rewards" => "79"} = first
      assert id2 == ids.b2

      assert {:ok, %{data: %{"miners" => %{"data" => [second]}}}} =
               run(state, query.(~s|limit: 1, cursor: "#{next}"|))

      assert %{"id" => id1, "rewards" => "55"} = second
      assert id1 == ids.b1
    end

    test "it returns the error of an invalid cursor", %{state: state} do
      assert {:ok, %{errors: [%{message: "invalid cursor: nope"}]}} =
               run(state, ~s|{ miners(cursor: "nope") { data { id } } }|)
    end
  end

  describe "miner and miner links" do
    test "it returns a miner", %{state: state, ids: ids} do
      assert {:ok, %{data: %{"miner" => %{"id" => id, "blocks" => 4, "rewards" => "55"}}}} =
               run(state, ~s|{ miner(id: "#{ids.b1}", role: BENEFICIARY) { id blocks rewards } }|)

      assert id == ids.b1
    end

    test "it returns an error when it's not found", %{state: state} do
      unknown = :aeapi.format_account_pubkey(<<99::256>>)

      assert {:ok, %{errors: [%{message: message}]}} =
               run(state, ~s|{ miner(id: "#{unknown}") { id } }|)

      assert message == "not found: #{unknown}"
    end

    test "it returns the beneficiaries of a miner", %{state: state, ids: ids} do
      assert {:ok, %{data: %{"minerLinks" => %{"data" => [first, second]}}}} =
               run(
                 state,
                 ~s|{ minerLinks(id: "#{ids.m1}") { data { id role blocks lastHeight } } }|
               )

      assert %{"id" => id2, "role" => "beneficiary", "blocks" => 1, "lastHeight" => 22} = first
      assert id2 == ids.b2
      assert %{"id" => id1, "blocks" => 3, "lastHeight" => 60} = second
      assert id1 == ids.b1
    end
  end

  describe "series" do
    test "it returns the series of a miner", %{state: state, ids: ids} do
      query = """
      { minerSeries(id: "#{ids.m1}", limit: 2) {
          nextCursor
          data { bucket interval startHeight endHeight blocks txs rewards blocksTotal }
      } }
      """

      assert {:ok,
              %{data: %{"minerSeries" => %{"data" => [bucket3, bucket2], "nextCursor" => next}}}} =
               run(state, query)

      assert %{"bucket" => 3, "interval" => 1, "startHeight" => 60, "endHeight" => 79} = bucket3
      assert %{"blocks" => 1, "rewards" => nil, "blocksTotal" => 4} = bucket3
      assert %{"bucket" => 2, "txs" => 2, "blocksTotal" => 3} = bucket2
      assert is_binary(next)
    end

    test "it returns the series of a miner for a scope and an interval", %{state: state, ids: ids} do
      query = """
      { minerSeries(id: "#{ids.m1}", fromHeight: 0, toHeight: 39, intervalBy: DAY) {
          data { bucket interval blocks }
      } }
      """

      assert {:ok,
              %{
                data: %{
                  "minerSeries" => %{
                    "data" => [%{"bucket" => 0, "interval" => 24, "blocks" => 4}]
                  }
                }
              }} =
               run(state, query)
    end

    test "it returns the network series", %{state: state} do
      query = """
      { miningSeries(interval: 24) {
          data { bucket interval blocks activeMiners newMiners hashrate minersTotal }
      } }
      """

      assert {:ok, %{data: %{"miningSeries" => %{"data" => [day]}}} = res} = run(state, query)

      refute res[:errors]
      assert %{"bucket" => 0, "interval" => 24, "blocks" => 6, "activeMiners" => 3} = day
      assert %{"newMiners" => 3, "minersTotal" => 3} = day
    end

    test "it returns the error of an invalid interval", %{state: state} do
      assert {:ok, %{errors: [%{message: "invalid query: interval=0"}]}} =
               run(state, "{ miningSeries(interval: 0) { data { bucket } } }")

      assert {:ok, %{errors: [%{message: "invalid query: interval=2"}]}} =
               run(state, "{ miningSeries(interval: 2) { data { bucket } } }")
    end
  end

  describe "buckets" do
    test "it returns a bucket", %{state: state} do
      assert {:ok,
              %{data: %{"miningBucket" => %{"bucket" => 1, "blocks" => 3, "rewards" => "125"}}}} =
               run(state, "{ miningBucket(bucket: 1) { bucket blocks rewards } }")

      assert {:ok, %{errors: [%{message: "not found: 99"}]}} =
               run(state, "{ miningBucket(bucket: 99) { bucket } }")
    end

    test "it returns the miners of a bucket", %{state: state, ids: ids} do
      query = "{ miningBucketMiners(bucket: 1) { data { id blocks txs blocksTotal } } }"

      assert {:ok, %{data: %{"miningBucketMiners" => %{"data" => [first, second]}}}} =
               run(state, query)

      assert %{"id" => id2, "blocks" => 1, "txs" => 1} = first
      assert id2 == ids.m2
      assert %{"id" => id1, "blocks" => 2, "txs" => 3, "blocksTotal" => 2} = second
      assert id1 == ids.m1
    end
  end

  defp run(state, query), do: Absinthe.run(query, @schema, context: %{state: state})

  defp ids do
    [m1, m2, m3] = Enum.map(MinerStatsFixtures.miners(), &:aeapi.format_account_pubkey/1)
    [b1, b2, b3] = Enum.map(MinerStatsFixtures.beneficiaries(), &:aeapi.format_account_pubkey/1)

    %{m1: m1, m2: m2, m3: m3, b1: b1, b2: b2, b3: b3}
  end
end
