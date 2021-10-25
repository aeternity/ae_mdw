defmodule Integration.AeMdwWeb.ContractControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag :integration

  alias AeMdwWeb.TestUtil

  import AeMdw.TestDbUtil

  import Assertions,
    only: [
      assert_maps_equal: 3
    ]

  @default_limit 10
  @second_range 11..20

  @contract0 "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"
  @contract1 "ct_2YEtP5SNQc7NLsZZV2DE7rbK7WTdmGMuw24F3Fqu9iDAk3qpFN"
  @contract2 "ct_2QKWLinRRozwA6wPAnW269hCHpkL1vcb2YCTrna94nP7rAPVU9"

  defp path(direction) when direction in [:forward, :backward] do
    Routes.contract_path(build_conn(), :logs, direction)
  end

  describe "logs" do
    test "get events of a contract with forward path", %{conn: conn} do
      path = path(:forward)
      conn = get(conn, path, contract_id: @contract0)

      assert response = json_response(conn, 200)
      assert Enum.count(response["data"]) == @default_limit
      assert Jason.encode!(response["data"]) == get_contract_logs_json(@contract0)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == @default_limit

      assert Jason.encode!(response_next["data"]) ==
               get_contract_logs_json(@contract0, :forward, @second_range)

      assert response_next["data"] != response["data"]

      Enum.each(response_next["data"], fn log_next ->
        Enum.each(response["data"], fn log -> assert log_next["call_txi"] > log["call_txi"] end)
      end)
    end

    test "get events of a contract with backward path", %{conn: conn} do
      path = path(:backward)
      conn = get(conn, path, contract_id: @contract0)

      assert response = json_response(conn, 200)
      assert Jason.encode!(response["data"]) == get_contract_logs_json(@contract0, :backward)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == @default_limit

      assert Jason.encode!(response_next["data"]) ==
               get_contract_logs_json(@contract0, :backward, @second_range)

      assert response_next["data"] != response["data"]

      Enum.each(response_next["data"], fn log_next ->
        Enum.each(response["data"], fn log -> assert log_next["call_txi"] < log["call_txi"] end)
      end)
    end

    test "get events from a remote contract call", %{conn: conn} do
      path = path(:forward)

      conn = get(conn, path, contract_id: @contract2)
      contract2_logs_json = get_contract_logs_json(@contract2)
      assert Jason.encode!(json_response(conn, 200)["data"]) == contract2_logs_json

      # remote call logged in caller (contract2)
      assert log_in_caller =
               contract2_logs_json
               |> Jason.decode!()
               |> Enum.find(fn log -> log["ext_caller_contract_id"] == @contract1 end)

      conn = get(conn, path, contract_id: @contract1)
      contract1_logs_json = get_contract_logs_json(@contract1)
      assert Jason.encode!(json_response(conn, 200)["data"]) == contract1_logs_json

      # remote call logged in called (contract1)
      assert log_in_called =
               contract1_logs_json
               |> Jason.decode!()
               |> Enum.find(fn log -> log["call_txi"] == log_in_caller["call_txi"] end)

      assert log_in_caller["contract_id"] == @contract2
      assert log_in_called["contract_id"] == @contract1
      assert log_in_called["parent_contract_id"] == @contract2

      assert_maps_equal(log_in_caller, log_in_called, [
        :args,
        :data,
        :event_hash,
        :call_tx_hash
      ])
    end

    test "renders error when the id is invalid", %{conn: conn} do
      contract_id = "ct_NoSuchContract"
      conn = get(conn, path(:forward), contract_id: contract_id)

      assert json_response(conn, 400) == %{
               "error" => TestUtil.handle_input(fn -> get_contract_logs_json(contract_id) end)
             }
    end

    test "when contract log doesn't have a creation txi, contract_id = nil", %{conn: conn} do
      contract_id = "ct_eJhrbPPS4V97VLKEVbSCJFpdA4uyXiZujQyLqMFoYV88TzDe6"

      assert %{"data" => contract_logs} =
               conn
               |> get(path(:forward), contract_id: contract_id)
               |> json_response(200)

      [
        %{
          "contract_id" => nil,
          "contract_txi" => -1,
          "ext_caller_contract_id" => "ct_eJhrbPPS4V97VLKEVbSCJFpdA4uyXiZujQyLqMFoYV88TzDe6",
          "ext_caller_contract_txi" => -1
        }
        | _rest
      ] = contract_logs
    end
  end

  describe "calls" do
    test "it gets calls from a contract", %{conn: conn} do
      contract_id = "ct_2uJthb5s1D8c8F8ZYMAZ6LYGWno5ubFnrmkkHLE1FBzN3JruQw"

      assert %{"data" => calls} =
               conn
               |> get("/contracts/calls/forward?contract_id=#{contract_id}")
               |> json_response(200)

      assert 10 = length(calls)
      assert %{"internal_tx" => %{"query" => query_b64}} = Enum.at(calls, 2)
      assert {:ok, _query} = Base.decode64(query_b64)
    end
  end
end
