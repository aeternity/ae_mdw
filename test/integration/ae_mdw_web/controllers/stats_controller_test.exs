defmodule Integration.AeMdwWeb.StatsControllerTest do
  use AeMdwWeb.ConnCase, async: false
  use Mneme

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util
  alias AeMdw.IntegrationUtil

  @moduletag :integration

  @default_limit 10

  describe "delta stats" do
    test "when no subpath it gets stats in backwards direction", %{conn: conn} do
      limit = 3
      state = State.new()
      {:ok, last_gen} = State.prev(state, Model.DeltaStat, nil)

      conn = get(conn, "/v3/stats/delta", limit: limit)
      response = json_response(conn, 200)

      assert ^limit = Enum.count(response["data"])

      assert response["data"]
             |> Enum.zip(last_gen..0)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert ^limit = Enum.count(response_next["data"])

      assert response_next["data"]
             |> Enum.zip((last_gen - limit)..(last_gen - @default_limit - 2))
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)
    end

    test "when direction=forward it gets stats starting from 1", %{conn: conn} do
      conn = get(conn, "/v3/stats/delta", direction: "forward")
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert response["data"]
             |> Enum.with_index(1)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert response_next["data"]
             |> Enum.zip((1 + @default_limit)..(10 + @default_limit))
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)
    end

    test "it gets generations with numeric range and default limit", %{conn: conn} do
      first = 47_800
      last = 48_000
      conn = get(conn, "/v3/stats/delta", scope: "gen:#{first}-#{last}")
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert response["data"]
             |> Enum.zip(first..last)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert response_next["data"]
             |> Enum.zip((first + @default_limit)..last)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)
    end

    test "it gets generations backwards with numeric range and limit=1", %{conn: conn} do
      first = 49_300
      last = 49_000
      limit = 1
      conn = get(conn, "/v3/stats/delta", scope: "gen:#{first}-#{last}", limit: limit)
      response = json_response(conn, 200)

      assert ^limit = Enum.count(response["data"])

      assert response["data"]
             |> Enum.zip(first..last)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert ^limit = Enum.count(response_next["data"])

      assert response_next["data"]
             |> Enum.zip((first - limit)..last)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)
    end

    test "renders error when the range is invalid", %{conn: conn} do
      range = "invalid"
      conn = get(conn, "/v3/stats/delta", scope: "gen:#{range}")
      error_msg = "invalid range: #{range}"

      assert %{"error" => ^error_msg} = json_response(conn, 400)
    end

    test "it returns correct results for a given height", %{conn: conn} do
      height = 501_015
      range = "#{height}-#{height}"

      assert %{
               "data" => [
                 %{
                   "auctions_started" => 0,
                   "block_reward" => 95_338_643_538_600_000_000,
                   "contracts_created" => 0,
                   "dev_reward" => 11_663_201_061_400_000_000,
                   "height" => ^height,
                   "names_activated" => 0,
                   "names_expired" => 0,
                   "names_revoked" => 0,
                   "oracles_expired" => 1,
                   "oracles_registered" => 0
                 }
               ]
             } =
               conn
               |> get("/v3/stats/delta", scope_type: "gen", range: range, limit: 1)
               |> json_response(200)
    end

    test "it returns no results when specifying an non-existent range", %{conn: conn} do
      invalid_gen = 10_000_000
      range = "#{invalid_gen}-#{invalid_gen}"

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn
               |> get("/v3/stats/delta", scope: "gen:#{range}")
               |> json_response(200)
    end
  end

  describe "total_stats" do
    test "when no subpath it gets stats in backwards direction", %{conn: conn} do
      limit = 100
      state = State.new()
      last_gen = Util.last_gen!(state) - 1

      conn = get(conn, "/v3/stats/total", limit: limit)
      response = json_response(conn, 200)

      assert ^limit = Enum.count(response["data"])

      assert response["data"]
             |> Enum.zip(last_gen..0)
             |> Enum.each(fn {%{
                                "height" => height,
                                "sum_block_reward" => sum_block_reward,
                                "sum_dev_reward" => sum_dev_reward
                              }, index} ->
               assert height == index
               assert sum_block_reward > 0
               assert sum_dev_reward > 0
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert ^limit = Enum.count(response_next["data"])

      stats_with_index =
        Enum.zip(response_next["data"], (last_gen - limit)..(last_gen - 2 * limit + 1))

      assert Enum.all?(stats_with_index, fn {%{"height" => height}, index} -> height == index end)
    end

    test "when direction=forward it gets stats starting from 1", %{conn: conn} do
      conn = get(conn, Routes.stats_path(conn, :total_stats, direction: "forward"))
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert response["data"]
             |> Enum.with_index(1)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert response_next["data"]
             |> Enum.zip(11..20)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)
    end

    test "it gets generations with numeric range and default limit", %{conn: conn} do
      first = 50_000
      last = 50_500
      conn = get(conn, "/v3/stats/total", scope: "gen:#{first}-#{last}")
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert response["data"]
             |> Enum.zip(first..last)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert response_next["data"]
             |> Enum.zip((first + @default_limit)..last)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)
    end

    test "it gets generations backwards with numeric range and limit=1", %{conn: conn} do
      first = 50_400
      last = 50_000
      limit = 1
      conn = get(conn, "/v3/stats/total", scope: "gen:#{first}-#{last}", limit: limit)
      response = json_response(conn, 200)

      assert ^limit = Enum.count(response["data"])

      assert response["data"]
             |> Enum.zip(first..last)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert ^limit = Enum.count(response_next["data"])

      assert response_next["data"]
             |> Enum.zip((first - limit)..last)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)
    end

    test "renders error when the range is invalid", %{conn: conn} do
      range = "invalid"
      conn = get(conn, "/v3/stats/total", scope: "gen:#{range}")
      error_msg = "invalid range: #{range}"

      assert %{"error" => ^error_msg} = json_response(conn, 400)
    end

    test "it returns correct results for a given height", %{conn: conn} do
      height = 506_056
      range = "#{height}-#{height}"

      auto_assert(
        %{
          "data" => [
            %{
              "active_auctions" => 130,
              "active_names" => 2634,
              "active_oracles" => 33,
              "burned_in_auctions" => 250_655_323_775_780_322_152_410,
              "contracts" => 1664,
              "height" => ^height,
              "inactive_names" => 538_281,
              "inactive_oracles" => 25,
              "last_tx_hash" => "th_2ZRar8CYU943eLBPr6kv3rNzdgzbrnFTS6jE8wWPwY5wFzTshY",
              "locked_in_auctions" => -220_759_724_327_999_999_910_848,
              "locked_in_channels" => 14_502_280_000_006_264_526,
              "open_channels" => 102,
              "sum_block_reward" => 106_403_172_824_736_927_928_811_744,
              "sum_dev_reward" => 8_453_404_352_599_072_614_268_863,
              "total_token_supply" => 390_989_171_992_825_584_568_749_640
            }
          ],
          "next" => nil,
          "prev" => nil
        } <-
          conn
          |> get("/v3/stats/total", scope_type: "gen", range: range, limit: 1)
          |> json_response(200)
      )
    end
  end

  describe "stats" do
    test "it returns stats", %{conn: conn} do
      assert %{
               "miners_count" => _miners_count,
               "fees_trend" => _fees_trend,
               "last_24hs_average_transaction_fees" => _last_24hs_average_transaction_fees,
               "last_24hs_transactions" => _last_24hs_transactions,
               "max_transactions_per_second" => _max_transactions_per_second,
               "max_transactions_per_second_block_hash" =>
                 _max_transactions_per_second_block_hash,
               "milliseconds_per_block" => _milliseconds_per_block,
               "transactions_trend" => _transactions_trend
             } =
               conn
               |> get("/v3/stats")
               |> json_response(200)
    end
  end

  describe "miners_stats" do
    test "it returns miners stats", %{conn: conn} do
      assert %{
               "data" => [
                 %{
                   "miner" => _miner,
                   "total_reward" => _total_reward
                 }
                 | _rest_of_data
               ]
             } =
               conn
               |> get("/v3/stats/miners")
               |> json_response(200)
    end

    test "pagination works", %{conn: conn} do
      IntegrationUtil.test_pagination(conn, %IntegrationUtil.PaginationParams{
        url: "/v3/stats/miners"
      })
    end
  end

  describe "transaction_stats" do
    test "it returns transaction stats", %{conn: conn} do
      assert %{
               "data" => [
                 %{
                   "count" => _count,
                   "end_date" => _end_date,
                   "start_date" => _start_date
                 }
                 | _rest_of_data
               ]
             } =
               conn
               |> get("/v3/stats/transactions")
               |> json_response(200)
    end

    test "pagination works", %{conn: conn} do
      IntegrationUtil.test_pagination(conn, %IntegrationUtil.PaginationParams{
        url: "/v3/stats/transactions"
      })
    end
  end

  describe "blocks_stats" do
    test "it returns blocks stats", %{conn: conn} do
      assert %{
               "data" => [
                 %{
                   "count" => _count,
                   "end_date" => _end_date,
                   "start_date" => _start_date
                 }
                 | _rest_of_data
               ]
             } =
               conn
               |> get("/v3/stats/blocks")
               |> json_response(200)
    end

    test "pagination works", %{conn: conn} do
      IntegrationUtil.test_pagination(conn, %IntegrationUtil.PaginationParams{
        url: "/v3/stats/blocks"
      })
    end
  end
end
