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

      conn = get(conn, "/v2/transfers", direction: "forward", kind: kind_prefix, limit: 100)
      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == 100

      assert Enum.all?(response["data"], fn %{"kind" => kind, "height" => height} ->
               kind == "accounts_genesis" and height == 0
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == 100

      assert Enum.all?(response_next["data"], fn %{"kind" => kind, "height" => height} ->
               kind == "accounts_genesis" and height == 0
             end)
    end

    test "returns fortuna accounts transfers filtering by kind", %{
      conn: conn
    } do
      kind_prefix = "accounts_fortuna"

      conn = get(conn, "/v2/transfers", direction: "forward", kind: kind_prefix, limit: 100)
      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == 100

      fortuna_height =
        :aec_governance.get_network_id()
        |> :aec_hard_forks.protocols_from_network_id()
        |> Map.get(3)

      assert Enum.all?(response["data"], fn %{
                                              "kind" => kind,
                                              "amount" => amount,
                                              "height" => height
                                            } ->
               kind == kind_prefix and amount > 0 and height == fortuna_height
             end)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == 100

      assert Enum.all?(response_next["data"], fn %{
                                                   "account_id" => account_id,
                                                   "kind" => kind,
                                                   "amount" => amount,
                                                   "height" => height
                                                 } ->
               if account_id in [
                    "ak_292g7TxJNGFfFXxsvFhJ5MfP6RzMrFGMJxRaY4Tx7byaBFQTg4",
                    "ak_2qdNcDDcELtsSPwot9ojjojuUxsucpCTcqbqZPT4nKjo1wtEEj"
                  ] do
                 kind == kind_prefix and amount == 0 and height == fortuna_height
               else
                 kind == kind_prefix and amount > 0 and height == fortuna_height
               end
             end)
    end

    test "returns a lima account transfer filtering by account", %{
      conn: conn
    } do
      account_id = "ak_zGR3f3QQ3BDAwhuPktLanrqcb6vrbViBr8RzU5VeqGNDbEyx9"

      conn = get(conn, "/v2/transfers", direction: "forward", account: account_id)
      response = json_response(conn, 200)

      lima_height =
        :aec_governance.get_network_id()
        |> :aec_hard_forks.protocols_from_network_id()
        |> Map.get(4)

      assert Enum.count(response["data"]) == 1

      assert %{
               "account_id" => ^account_id,
               "kind" => "accounts_lima",
               "amount" => 1_186_111_575_000_000_000_000,
               "height" => ^lima_height
             } = List.first(response["data"])
    end

    test "renders error when the range is invalid", %{conn: conn} do
      range = "invalid"
      error_msg = "invalid range: #{range}"
      conn = get(conn, "/v2/transfers", scope: "gen:#{range}")

      assert %{"error" => ^error_msg} = json_response(conn, 400)
    end
  end
end
