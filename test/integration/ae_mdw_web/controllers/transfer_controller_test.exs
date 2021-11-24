defmodule Integration.AeMdwWeb.TransferControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model

  require Model

  @moduletag :integration

  @default_limit 10

  describe "transfers" do
    test "when direction=forward it gets unfiltered transfers forwards", %{conn: conn} do
      direction = "forward"
      conn = get(conn, "/transfers/#{direction}")
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
    end

    test "when direction=backward it gets unfiltered transfers backwards", %{conn: conn} do
      direction = "backward"
      limit = 3

      conn = get(conn, "/transfers/#{direction}?limit=#{limit}")
      response = json_response(conn, 200)

      assert ^limit = Enum.count(response["data"])

      heights = Enum.map(response["data"], fn %{"height" => height} -> height end)
      reverse_heights = Enum.reverse(heights)

      assert ^reverse_heights = Enum.sort(heights)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == limit

      heights2 = Enum.map(response_next["data"], fn %{"height" => height} -> height end)
      reverse_heights2 = Enum.reverse(heights2)

      assert ^reverse_heights2 = Enum.sort(heights2)
      assert Enum.at(heights2, 0) <= Enum.at(heights, limit - 1)
    end

    test "it fails when getting transfers with a txis range", %{conn: conn} do
      range = "0-10"
      conn = get(conn, "/transfers/txi/#{range}")
      error_msg = "invalid scope: txi"

      assert %{"error" => ^error_msg} = json_response(conn, 400)
    end

    test "it gets transfers within gen range and limit=3", %{conn: conn} do
      first = 5_000
      last = 0
      range = "#{first}-#{last}"
      limit = 3
      conn = get(conn, "/transfers/gen/#{range}?limit=#{limit}")
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
    end

    test "when providing account filter, it returns transfers filtered by account", %{conn: conn} do
      account_pk = "ak_21rna3xrD7p32U3vpXPSmanjsnSGnh6BWFPC9Pe7pYxeAW8PpS"

      conn = get(conn, "/transfers/forward?account=#{account_pk}")
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
    end

    test "when providing kind prefix filter, it returns transfers filtered by kind prefix", %{
      conn: conn
    } do
      kind_prefix = "fee_"

      conn = get(conn, "/transfers/forward?kind=#{kind_prefix}")
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

      conn = get(conn, "/transfers/gen/#{first_gen}-#{last_gen}?kind=#{kind_prefix}")
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

    test "when providing account and kind prefix filters, it returns transfers filtered by account and kind",
         %{conn: conn} do
      account_pk = "ak_21rna3xrD7p32U3vpXPSmanjsnSGnh6BWFPC9Pe7pYxeAW8PpS"
      kind_prefix = "reward"

      conn = get(conn, "/transfers/forward?account=#{account_pk}&kind=#{kind_prefix}")
      response = json_response(conn, 200)

      assert @default_limit = Enum.count(response["data"])

      assert Enum.all?(response["data"], fn %{"account_id" => account_id, "kind" => kind} ->
               account_id == account_pk and String.starts_with?(kind, kind_prefix)
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert @default_limit = Enum.count(response_next["data"])

      assert Enum.all?(response_next["data"], fn %{"account_id" => account_id, "kind" => kind} ->
               account_id == account_pk and String.starts_with?(kind, kind_prefix)
             end)
    end

    test "renders error when the range is invalid", %{conn: conn} do
      range = "invalid"
      error_msg = "invalid range: #{range}"
      conn = get(conn, "/transfers/gen/#{range}")

      assert %{"error" => ^error_msg} = json_response(conn, 400)
    end
  end
end
