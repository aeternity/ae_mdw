defmodule Integration.AeMdwWeb.StatsControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util

  @moduletag :integration

  @default_limit 10

  describe "stats (v1)" do
    test "gets stats backwards as default direction", %{conn: conn} do
      limit = 3
      last_gen = Util.last_gen()

      conn = get(conn, "/stats", limit: limit)
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
      conn = get(conn, "/stats", direction: "forward")
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
      first = 305_000
      last = 305_100
      conn = get(conn, "/stats", scope_type: "gen", range: "#{first}-#{last}")
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
      first = 305_100
      last = 305_000
      limit = 1
      conn = get(conn, "/stats", scope: "gen:#{first}-#{last}", limit: limit)
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
      conn = get(conn, "/stats", scope_type: "gen", range: range)
      error_msg = "invalid range: #{range}"

      assert %{"error" => ^error_msg} = json_response(conn, 400)
    end

    test "it returns correct results for a given height", %{conn: conn} do
      height = 506_056
      range = "#{height}-#{height}"

      assert %{
               "data" => [
                 %{
                   "active_auctions" => 1138,
                   "active_names" => 2634,
                   "active_oracles" => 33,
                   "block_reward" => 94_447_969_004_862_000_000,
                   "contracts" => 1681,
                   "dev_reward" => 11_554_240_877_138_000_000,
                   "height" => ^height,
                   "inactive_names" => 557_159,
                   "inactive_oracles" => 149
                 }
               ]
             } =
               conn
               |> get("/stats", scope_type: "gen", range: range, limit: 1)
               |> json_response(200)
    end
  end

  describe "delta stats" do
    test "when no subpath it gets stats in backwards direction", %{conn: conn} do
      limit = 3
      {:ok, last_gen} = Database.last_key(Model.DeltaStat)

      conn = get(conn, "/v2/deltastats", limit: limit)
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
      conn = get(conn, "/v2/deltastats", direction: "forward")
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
      conn = get(conn, "/v2/deltastats", scope: "gen:#{first}-#{last}")
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
      conn = get(conn, "/v2/deltastats", scope: "gen:#{first}-#{last}", limit: limit)
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
      conn = get(conn, "/v2/deltastats", scope: "gen:#{range}")
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
               |> get("/v2/deltastats", scope_type: "gen", range: range, limit: 1)
               |> json_response(200)
    end

    test "it returns no results when specifying an non-existent range", %{conn: conn} do
      invalid_gen = 10_000_000
      range = "#{invalid_gen}-#{invalid_gen}"

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn
               |> get("/v2/deltastats", scope: "gen:#{range}")
               |> json_response(200)
    end
  end

  describe "total_stats" do
    test "when no subpath it gets stats in backwards direction", %{conn: conn} do
      limit = 100
      last_gen = Util.last_gen() - 1

      conn = get(conn, "/v2/totalstats", limit: limit)
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
      conn = get(conn, "/v2/totalstats", scope: "gen:#{first}-#{last}")
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
      conn = get(conn, "/v2/totalstats", scope: "gen:#{first}-#{last}", limit: limit)
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
      conn = get(conn, "/v2/totalstats", scope: "gen:#{range}")
      error_msg = "invalid range: #{range}"

      assert %{"error" => ^error_msg} = json_response(conn, 400)
    end

    test "it returns correct results for a given height", %{conn: conn} do
      height = 506_056
      range = "#{height}-#{height}"

      assert %{
               "data" => [
                 %{
                   "active_auctions" => 1138,
                   "active_names" => 2634,
                   "active_oracles" => 33,
                   "sum_block_reward" => 106_403_172_824_736_927_928_811_744,
                   "contracts" => 1681,
                   "sum_dev_reward" => 8_453_404_352_599_072_614_268_863,
                   "height" => ^height,
                   "inactive_names" => 557_159,
                   "inactive_oracles" => 149
                 }
               ]
             } =
               conn
               |> get("/v2/totalstats", scope_type: "gen", range: range, limit: 1)
               |> json_response(200)
    end
  end
end
