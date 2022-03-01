defmodule Integration.AeMdwWeb.StatsControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Util

  @moduletag :integration

  @default_limit 10

  describe "delta stats" do
    test "when no subpath it gets stats in backwards direction", %{conn: conn} do
      limit = 3
      last_gen = Util.last_gen()

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
      first = 55_000
      last = 55_200
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
      first = 56_300
      last = 56_000
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
  end

  describe "total_stats" do
    test "when no subpath it gets stats in backwards direction", %{conn: conn} do
      limit = 100
      last_gen = Util.last_gen()

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
      conn = get(conn, "/v2/totalstats", direction: "forward")
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert response["data"]
             |> Enum.with_index(0)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert response_next["data"]
             |> Enum.zip(10..19)
             |> Enum.all?(fn {%{"height" => height}, index} -> height == index end)
    end

    test "it gets generations with numeric range and default limit", %{conn: conn} do
      first = 305_000
      last = 305_100
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
      first = 305_100
      last = 305_000
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
  end
end
