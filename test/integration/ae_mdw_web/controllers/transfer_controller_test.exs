defmodule Integration.AeMdwWeb.TransferControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util

  require Model

  @moduletag :integration

  @default_limit 10

  describe "transfers" do
    test "when direction=forward it gets unfiltered transfers forwards", %{conn: conn} do
      direction = "forward"
      conn = get(conn, "/v2/transfers", direction: direction)
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      heights = Enum.map(response["data"], fn %{"height" => height} -> height end)

      assert ^heights = Enum.sort(heights)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == @default_limit

      heights2 = Enum.map(response_next["data"], fn %{"height" => height} -> height end)

      assert ^heights2 = Enum.sort(heights2)
      assert Enum.at(heights2, 0) >= Enum.at(heights, @default_limit - 1)

      %{"data" => prev_data} = conn |> get(response_next["prev"]) |> json_response(200)

      assert ^prev_data = response["data"]
    end

    test "when direction=backward it gets unfiltered transfers backwards", %{conn: conn} do
      direction = "backward"
      limit = 3

      conn = get(conn, "/v2/transfers", direction: direction, limit: limit)
      response = json_response(conn, 200)

      assert ^limit = Enum.count(response["data"])

      heights = Enum.map(response["data"], fn %{"height" => height} -> height end)
      reverse_heights = Enum.reverse(heights)

      assert ^reverse_heights = Enum.sort(heights)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert ^limit = Enum.count(response_next["data"])

      heights2 = Enum.map(response_next["data"], fn %{"height" => height} -> height end)
      reverse_heights2 = Enum.reverse(heights2)

      assert ^reverse_heights2 = Enum.sort(heights2)
      assert Enum.at(heights2, 0) <= Enum.at(heights, limit - 1)

      %{"data" => prev_data} = conn |> get(response_next["prev"]) |> json_response(200)

      assert ^prev_data = response["data"]
    end

    test "when scoping by txis, it returns transfers inside that range", %{conn: conn} do
      first = 200_000
      last = 300_000
      limit = 3
      state = State.new()
      conn = get(conn, "/transfers", scope: "txi:#{first}-#{last}", limit: limit)
      response = json_response(conn, 200)
      first_gen = Util.txi_to_gen(state, first)
      last_gen = Util.txi_to_gen(state, last)

      assert ^limit = Enum.count(response["data"])

      heights = Enum.map(response["data"], fn %{"height" => height} -> height end)

      assert ^heights = Enum.sort(heights)
      assert Enum.at(heights, 0) >= first_gen

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert ^limit = Enum.count(response_next["data"])

      heights2 = Enum.map(response_next["data"], fn %{"height" => height} -> height end)

      assert ^heights2 = Enum.sort(heights2)
      assert Enum.at(heights2, 0) >= Enum.at(heights, limit - 1)
      assert List.last(heights2) <= last_gen

      %{"data" => prev_data} = conn |> get(response_next["prev"]) |> json_response(200)

      assert ^prev_data = response["data"]
    end

    test "when scoping by txis backwards, it returns transfers inside that range", %{conn: conn} do
      first = 300_000
      last = 200_000
      limit = 3
      state = State.new()
      conn = get(conn, "/transfers", scope: "txi:#{first}-#{last}", limit: limit)
      response = json_response(conn, 200)
      first_gen = Util.txi_to_gen(state, first)
      last_gen = Util.txi_to_gen(state, last)

      assert ^limit = Enum.count(response["data"])

      heights =
        response["data"] |> Enum.map(fn %{"height" => height} -> height end) |> Enum.reverse()

      assert ^heights = Enum.sort(heights)
      assert Enum.at(heights, 0) >= last_gen

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert ^limit = Enum.count(response_next["data"])

      heights2 =
        response_next["data"]
        |> Enum.map(fn %{"height" => height} -> height end)
        |> Enum.reverse()

      assert ^heights2 = Enum.sort(heights2)
      assert Enum.at(heights2, 0) <= Enum.at(heights, limit - 1)
      assert List.last(heights2) <= first_gen

      %{"data" => prev_data} = conn |> get(response_next["prev"]) |> json_response(200)

      assert ^prev_data = response["data"]
    end

    test "it gets transfers within gen range and limit=3", %{conn: conn} do
      first = 5_000
      last = 0
      range = "#{first}-#{last}"
      limit = 3
      conn = get(conn, "/transfers", scope: "gen:#{range}", limit: limit)
      response = json_response(conn, 200)

      assert ^limit = Enum.count(response["data"])

      heights = Enum.map(response["data"], fn %{"height" => height} -> height end)

      assert Enum.all?(heights, fn height -> last <= height and height <= first end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert ^limit = Enum.count(response_next["data"])
      heights2 = Enum.map(response_next["data"], fn %{"height" => height} -> height end)

      assert Enum.all?(heights2, fn height -> last <= height and height <= first end)
      assert Enum.at(heights2, 0) <= Enum.at(heights, limit - 1)

      %{"data" => prev_data} = conn |> get(response_next["prev"]) |> json_response(200)

      assert ^prev_data = response["data"]
    end

    test "when providing account filter, it returns transfers filtered by account", %{conn: conn} do
      account_pk = "ak_21rna3xrD7p32U3vpXPSmanjsnSGnh6BWFPC9Pe7pYxeAW8PpS"

      conn = get(conn, "/v2/transfers", direction: "forward", account: account_pk)
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert Enum.all?(response["data"], fn %{"account_id" => account_id} ->
               account_id == account_pk
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert Enum.all?(response_next["data"], fn %{"account_id" => account_id} ->
               account_id == account_pk
             end)

      %{"data" => prev_data} = conn |> get(response_next["prev"]) |> json_response(200)

      assert ^prev_data = response["data"]
    end

    test "when providing account filter backwards, it returns transfers filtered by account", %{
      conn: conn
    } do
      account_pk = "ak_21rna3xrD7p32U3vpXPSmanjsnSGnh6BWFPC9Pe7pYxeAW8PpS"

      conn = get(conn, "/v2/transfers", account: account_pk)
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      heights = Enum.map(response["data"], fn %{"height" => height} -> height end)
      reverse_heights = Enum.reverse(heights)

      assert ^reverse_heights = Enum.sort(heights)

      assert Enum.all?(response["data"], fn %{"account_id" => account_id} ->
               account_id == account_pk
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      heights2 = Enum.map(response_next["data"], fn %{"height" => height} -> height end)
      reverse_heights2 = Enum.reverse(heights2)

      assert ^reverse_heights2 = Enum.sort(heights2)

      assert @default_limit = Enum.count(response_next["data"])

      assert Enum.all?(response_next["data"], fn %{"account_id" => account_id} ->
               account_id == account_pk
             end)

      %{"data" => prev_data} = conn |> get(response_next["prev"]) |> json_response(200)

      assert ^prev_data = response["data"]
    end

    test "when providing kind prefix filter, it returns transfers filtered by kind prefix", %{
      conn: conn
    } do
      kind_prefix = "fee_"

      conn = get(conn, "/v2/transfers", direction: "forward", kind: kind_prefix)
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert Enum.all?(response["data"], fn %{"kind" => kind} ->
               String.starts_with?(kind, kind_prefix)
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert Enum.all?(response_next["data"], fn %{"kind" => kind} ->
               String.starts_with?(kind, kind_prefix)
             end)
    end

    test "when providing kind prefix filter and gen scope, it returns transfers filtered by kind prefix inside the gen scope",
         %{conn: conn} do
      kind_prefix = "fee_"
      first_gen = 0
      last_gen = 104_553

      conn = get(conn, "/transfers", scope: "gen:#{first_gen}-#{last_gen}", kind: kind_prefix)
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert Enum.all?(response["data"], fn %{"kind" => kind, "height" => height} ->
               String.starts_with?(kind, kind_prefix) and first_gen <= height and
                 height <= last_gen
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert Enum.all?(response_next["data"], fn %{"kind" => kind, "height" => height} ->
               String.starts_with?(kind, kind_prefix) and first_gen <= height and
                 height <= last_gen
             end)
    end

    test "when filtering by kind prefix filter and gen scope backwards, it returns transfers accordingly",
         %{conn: conn} do
      kind_prefix = "fee_"
      first_gen = 104_553
      last_gen = 0

      conn = get(conn, "/transfers", scope: "gen:#{first_gen}-#{last_gen}", kind: kind_prefix)
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert Enum.all?(response["data"], fn %{"kind" => kind, "height" => height} ->
               String.starts_with?(kind, kind_prefix) and last_gen <= height and
                 height <= first_gen
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert Enum.all?(response_next["data"], fn %{"kind" => kind, "height" => height} ->
               String.starts_with?(kind, kind_prefix) and last_gen <= height and
                 height <= first_gen
             end)
    end

    test "when filtering by kind prefix filter and direction=backwards, it returns transfers accordingly",
         %{conn: conn} do
      kind_prefix = "fee_"

      conn = get(conn, "/transfers", kind: kind_prefix)
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert Enum.all?(response["data"], fn %{"kind" => kind} ->
               String.starts_with?(kind, kind_prefix)
             end)

      heights =
        response["data"]
        |> Enum.map(fn %{"height" => height} -> height end)
        |> Enum.reverse()

      assert ^heights = Enum.sort(heights)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert Enum.all?(response_next["data"], fn %{"kind" => kind} ->
               String.starts_with?(kind, kind_prefix)
             end)

      heights =
        response_next["data"]
        |> Enum.map(fn %{"height" => height} -> height end)
        |> Enum.reverse()

      assert ^heights = Enum.sort(heights)
    end

    test "when providing account and kind prefix filters, it returns transfers filtered by account and kind",
         %{conn: conn} do
      account_pk = "ak_JFkVmYeY9iP4gmKexBHx7t1aAj1R6FGvBdWaZRBVLuuzWv83j"
      kind_prefix = "fee_"

      conn =
        get(conn, "/v2/transfers", direction: "forward", account: account_pk, kind: kind_prefix)

      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert Enum.all?(response["data"], fn %{"account_id" => account_id, "kind" => kind} ->
               account_id == account_pk and String.starts_with?(kind, kind_prefix)
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) > 0

      assert Enum.all?(response_next["data"], fn %{"account_id" => account_id, "kind" => kind} ->
               account_id == account_pk and String.starts_with?(kind, kind_prefix)
             end)
    end

    test "when providing account and kind prefix filters and backwards, it returns transfers accordingly",
         %{conn: conn} do
      account_pk = "ak_JFkVmYeY9iP4gmKexBHx7t1aAj1R6FGvBdWaZRBVLuuzWv83j"
      kind_prefix = "fee_"
      from = 500_000
      to = 50_000

      conn =
        get(conn, "/v2/transfers",
          scope: "gen:#{from}-#{to}",
          account: account_pk,
          kind: kind_prefix
        )

      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert Enum.all?(response["data"], fn %{"account_id" => account_id, "kind" => kind} ->
               account_id == account_pk and String.starts_with?(kind, kind_prefix)
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) > 0

      assert Enum.all?(response_next["data"], fn %{"account_id" => account_id, "kind" => kind} ->
               account_id == account_pk and String.starts_with?(kind, kind_prefix)
             end)
    end

    test "renders error when the range is invalid", %{conn: conn} do
      range = "invalid"
      error_msg = "invalid range: #{range}"
      conn = get(conn, "/transfers", scope: "gen:#{range}")

      assert %{"error" => ^error_msg} = json_response(conn, 400)
    end
  end
end
