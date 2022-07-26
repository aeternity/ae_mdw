defmodule AeMdwWeb.TransferControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Db.HardforkPresets

  setup_all _ do
    HardforkPresets.import_account_presets()
    :ok
  end

  describe "transfers" do
    test "returns hardfork kind transfers with accounts prefix", %{
      conn: conn
    } do
      kind_prefix = "accounts"
      kinds = ~w(accounts_minerva accounts_fortuna accounts_lima)

      conn = get(conn, "/v2/transfers", direction: "forward", kind: kind_prefix, limit: 100)
      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == 100

      assert Enum.all?(response["data"], fn %{"kind" => kind} ->
               String.starts_with?(kind, kind_prefix) and kind in kinds
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == 100

      assert Enum.all?(response_next["data"], fn %{"kind" => kind} ->
               String.starts_with?(kind, kind_prefix) and kind in kinds
             end)
    end

    test "returns fortuna accounts transfers filtering by kind", %{
      conn: conn
    } do
      kind_prefix = "accounts_fortuna"

      conn = get(conn, "/v2/transfers", direction: "forward", kind: kind_prefix, limit: 100)
      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == 100

      assert Enum.all?(response["data"], fn %{"kind" => kind} ->
               kind == kind_prefix
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == 100

      assert Enum.all?(response_next["data"], fn %{"kind" => kind} ->
               kind == kind_prefix
             end)
    end

    test "renders error when the range is invalid", %{conn: conn} do
      range = "invalid"
      error_msg = "invalid range: #{range}"
      conn = get(conn, "/v2/transfers", scope: "gen:#{range}")

      assert %{"error" => ^error_msg} = json_response(conn, 400)
    end
  end
end
