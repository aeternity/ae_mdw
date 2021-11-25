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

      assert ^limit = Enum.count(response_next["data"])

      heights2 = Enum.map(response_next["data"], fn %{"height" => height} -> height end)
      reverse_heights2 = Enum.reverse(heights2)

      assert ^reverse_heights2 = Enum.sort(heights2)
      assert Enum.at(heights2, 0) <= Enum.at(heights, limit - 1)
    end

    test "when scoping by txis, it returns transfers inside that range", %{conn: conn} do
      first = 200_000
      last = 300_000
      limit = 3
      conn = get(conn, "/transfers/txi/#{first}-#{last}?limit=#{limit}")
      response = json_response(conn, 200)

      assert ^limit = Enum.count(response["data"])

      ref_txis = Enum.map(response["data"], fn %{"ref_txi" => ref_txi} -> ref_txi end)

      assert ^ref_txis = Enum.sort(ref_txis)
      assert Enum.all?(ref_txis, fn ref_txi -> first <= ref_txi and ref_txi <= last end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert ^limit = Enum.count(response_next["data"])

      ref_txis2 = Enum.map(response_next["data"], fn %{"ref_txi" => ref_txi} -> ref_txi end)

      assert ^ref_txis2 = Enum.sort(ref_txis2)
      assert Enum.at(ref_txis2, 0) >= Enum.at(ref_txis, limit - 1)
      assert Enum.all?(ref_txis2, fn ref_txi -> first <= ref_txi and ref_txi <= last end)
    end

    test "when scoping by txis backwards, it returns transfers inside that range", %{conn: conn} do
      first = 300_000
      last = 200_000
      limit = 3
      conn = get(conn, "/transfers/txi/#{first}-#{last}?limit=#{limit}")
      response = json_response(conn, 200)

      assert ^limit = Enum.count(response["data"])

      ref_txis = Enum.map(response["data"], fn %{"ref_txi" => ref_txi} -> ref_txi end)
      ref_txis = Enum.reverse(ref_txis)

      assert ^ref_txis = Enum.sort(ref_txis)
      assert Enum.all?(ref_txis, fn ref_txi -> last <= ref_txi and ref_txi <= first end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert ^limit = Enum.count(response_next["data"])

      ref_txis2 = Enum.map(response_next["data"], fn %{"ref_txi" => ref_txi} -> ref_txi end)
      ref_txis2 = Enum.reverse(ref_txis2)

      assert ^ref_txis2 = Enum.sort(ref_txis2)
      assert Enum.at(ref_txis2, 0) <= Enum.at(ref_txis, limit - 1)
      assert Enum.all?(ref_txis2, fn ref_txi -> last <= ref_txi and ref_txi <= first end)
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

    test "when providing account filter backwards, it returns transfers filtered by account", %{
      conn: conn
    } do
      account_pk = "ak_21rna3xrD7p32U3vpXPSmanjsnSGnh6BWFPC9Pe7pYxeAW8PpS"

      conn = get(conn, "/transfers/backward?account=#{account_pk}")
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

    test "when filtering by kind prefix filter and gen scope backwards, it returns transfers accordingly",
         %{conn: conn} do
      kind_prefix = "fee_"
      first_gen = 104_553
      last_gen = 0

      conn = get(conn, "/transfers/gen/#{first_gen}-#{last_gen}?kind=#{kind_prefix}")
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
