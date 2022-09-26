defmodule Integration.AeMdwWeb.ContractControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag :integration

  @default_limit 10

  @contract0 "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"
  @contract1 "ct_2YEtP5SNQc7NLsZZV2DE7rbK7WTdmGMuw24F3Fqu9iDAk3qpFN"
  @contract2 "ct_2QKWLinRRozwA6wPAnW269hCHpkL1vcb2YCTrna94nP7rAPVU9"

  describe "logs" do
    test "it get logs backwards without any filters", %{conn: conn} do
      assert %{"data" => logs, "next" => next} =
               conn |> get("/v2/contracts/logs") |> json_response(200)

      call_txis =
        logs
        |> Enum.map(fn %{"call_txi" => call_txi} -> call_txi end)
        |> Enum.reverse()

      assert @default_limit = length(call_txis)
      assert ^call_txis = Enum.sort(call_txis)

      assert %{"data" => next_logs} = conn |> get(next) |> json_response(200)

      next_call_txis =
        next_logs
        |> Enum.map(fn %{"call_txi" => call_txi} -> call_txi end)
        |> Enum.reverse()

      assert @default_limit = length(next_call_txis)
      assert ^next_call_txis = Enum.sort(next_call_txis)
      assert Enum.at(call_txis, @default_limit - 1) >= Enum.at(next_call_txis, 0)
    end

    test "it get logs backwards without any filters, with backwards path", %{conn: conn} do
      assert %{"data" => logs, "next" => next} =
               conn |> get("/v2/contracts/logs") |> json_response(200)

      call_txis =
        logs
        |> Enum.map(fn %{"call_txi" => call_txi} -> call_txi end)
        |> Enum.reverse()

      assert @default_limit = length(call_txis)
      assert ^call_txis = Enum.sort(call_txis)

      assert %{"data" => next_logs} = conn |> get(next) |> json_response(200)

      next_call_txis =
        next_logs
        |> Enum.map(fn %{"call_txi" => call_txi} -> call_txi end)
        |> Enum.reverse()

      assert @default_limit = length(next_call_txis)
      assert ^next_call_txis = Enum.sort(next_call_txis)
      assert Enum.at(call_txis, @default_limit - 1) >= Enum.at(next_call_txis, 0)
    end

    test "is get logs forward without any filters", %{conn: conn} do
      assert %{"data" => logs, "next" => next} =
               conn
               |> get("/v2/contracts/logs", direction: "forward")
               |> json_response(200)

      call_txis = Enum.map(logs, fn %{"call_txi" => call_txi} -> call_txi end)

      assert @default_limit = length(call_txis)
      assert ^call_txis = Enum.sort(call_txis)

      assert %{"data" => next_logs} = conn |> get(next) |> json_response(200)

      next_call_txis = Enum.map(next_logs, fn %{"call_txi" => call_txi} -> call_txi end)

      assert @default_limit = length(next_call_txis)
      assert ^next_call_txis = Enum.sort(next_call_txis)
      assert Enum.at(call_txis, @default_limit - 1) <= Enum.at(next_call_txis, 0)
    end

    test "it gets logs forward belonging to a contract", %{conn: conn} do
      contract_id = @contract0

      assert %{"data" => logs, "next" => next} =
               conn
               |> get("/v2/contracts/logs", direction: "forward", contract_id: contract_id)
               |> json_response(200)

      create_txis = Enum.map(logs, fn %{"contract_txi" => create_txi} -> create_txi end)

      assert @default_limit = length(create_txis)
      assert ^create_txis = Enum.sort(create_txis)
      assert Enum.all?(logs, &match?(%{"contract_id" => ^contract_id}, &1))

      assert %{"data" => next_logs} = conn |> get(next) |> json_response(200)

      next_create_txis = Enum.map(next_logs, fn %{"contract_txi" => create_txi} -> create_txi end)

      assert @default_limit = length(next_create_txis)
      assert ^next_create_txis = Enum.sort(next_create_txis)
      assert Enum.all?(next_logs, &match?(%{"contract_id" => ^contract_id}, &1))
      assert Enum.at(create_txis, @default_limit - 1) <= Enum.at(next_create_txis, 0)
    end

    test "it get logs from a remote contract call", %{conn: conn} do
      contract_id = @contract2
      ext_contract_id = @contract1

      assert %{"data" => caller_logs} =
               conn
               |> get("/v2/contracts/logs", direction: "forward", contract_id: contract_id)
               |> json_response(200)

      assert Enum.all?(caller_logs, &match?(%{"contract_id" => ^contract_id}, &1))

      # remote call logged in caller (contract2)
      assert log_in_caller =
               Enum.find(
                 caller_logs,
                 &match?(%{"ext_caller_contract_id" => ^ext_contract_id}, &1)
               )

      assert %{"data" => called_logs} =
               conn
               |> get("/v2/contracts/logs", direction: "forward", contract_id: ext_contract_id)
               |> json_response(200)

      # remote call logged in called (contract1)
      assert log_in_called =
               Enum.find(called_logs, fn log -> log["call_txi"] == log_in_caller["call_txi"] end)

      assert @contract2 = log_in_caller["contract_id"]
      assert @contract1 = log_in_called["contract_id"]
      assert @contract2 = log_in_called["parent_contract_id"]

      assert Enum.all?(
               ~w(args data event_hash call_tx_hash),
               &(log_in_caller[&1] == log_in_called[&1])
             )
    end

    test "get events from a contract init", %{conn: conn} do
      contract_id = "ct_2PpG8gqRqA5Cp1nidyUka4PRQpdVux295xtqPSosQcJwYM2bYf"

      %{"data" => data} =
        conn
        |> get("/v2/contracts/logs", direction: "forward", contract_id: contract_id)
        |> json_response(200)

      assert %{"call_txi" => call_txi, "contract_txi" => contract_txi} = hd(data)
      assert call_txi == contract_txi
    end

    test "get internal calls from a contract init", %{conn: conn} do
      contract_id = "ct_tDn6g6Rz1y5X6TKj4o2yGVgdw73Fv3Grk1iubct47GbYXSYp1"

      %{"data" => data} =
        conn
        |> get("/v2/contracts/calls", direction: "forward", contract_id: contract_id)
        |> json_response(200)

      assert %{
               "function" => "Call.amount",
               "call_txi" => call_txi,
               "contract_txi" => contract_txi
             } = hd(data)

      assert call_txi == contract_txi
    end

    test "renders error when the id is invalid", %{conn: conn} do
      contract_id = "ct_NoSuchContract"
      error_msg = "invalid id: #{contract_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/contracts/logs", direction: "forward", contract_id: contract_id)
               |> json_response(400)
    end

    test "when contract log doesn't have a creation txi, contract_id shouldn't be nil", %{
      conn: conn
    } do
      contract_id = "ct_eJhrbPPS4V97VLKEVbSCJFpdA4uyXiZujQyLqMFoYV88TzDe6"

      assert %{"data" => logs} =
               conn
               |> get("/v2/contracts/logs", direction: "forward", contract_id: contract_id)
               |> json_response(200)

      assert [
               %{
                 "contract_id" => ^contract_id,
                 "contract_txi" => -1,
                 "ext_caller_contract_id" =>
                   "ct_eJhrbPPS4V97VLKEVbSCJFpdA4uyXiZujQyLqMFoYV88TzDe6",
                 "ext_caller_contract_txi" => -1
               }
               | rest
             ] = logs

      assert Enum.all?(rest, &match?(%{"contract_id" => ^contract_id}, &1))
    end

    test "it returns the called filtered by event hash", %{conn: conn} do
      event = "TipReceived"
      event_hash = event |> :aec_hash.blake2b_256_hash() |> Base.hex_encode32()

      assert %{"data" => logs, "next" => next} =
               conn
               |> get("/v2/contracts/logs", event: event)
               |> json_response(200)

      call_txis = logs |> Enum.map(fn %{"call_txi" => call_txi} -> call_txi end) |> Enum.reverse()

      assert @default_limit = length(call_txis)
      assert ^call_txis = Enum.sort(call_txis)
      assert Enum.all?(logs, &match?(%{"event_hash" => ^event_hash}, &1))

      assert %{"data" => next_logs} = conn |> get(next) |> json_response(200)

      next_call_txis =
        next_logs |> Enum.map(fn %{"call_txi" => call_txi} -> call_txi end) |> Enum.reverse()

      assert @default_limit = length(next_call_txis)
      assert ^next_call_txis = Enum.sort(next_call_txis)
      assert Enum.at(call_txis, @default_limit - 1) >= Enum.at(next_call_txis, 0)
    end

    test "it returns calls filtered by data prefix", %{conn: conn} do
      data_prefix = "aeternity.com"

      assert %{"data" => logs} =
               conn
               |> get("/v2/contracts/logs", data: URI.encode(data_prefix))
               |> json_response(200)

      data_call_txis =
        logs
        |> Enum.map(fn %{"data" => data, "call_txi" => call_txi} -> {data, call_txi} end)
        |> Enum.reverse()

      assert length(data_call_txis) > 0
      assert ^data_call_txis = Enum.sort(data_call_txis)
      assert Enum.all?(logs, fn %{"data" => data} -> String.starts_with?(data, data_prefix) end)
    end
  end

  describe "calls" do
    test "it get calls backwards without any filters", %{conn: conn} do
      assert %{"data" => calls, "next" => next} =
               conn |> get("/v2/contracts/calls") |> json_response(200)

      call_txis =
        calls
        |> Enum.map(fn %{"call_txi" => call_txi} -> call_txi end)
        |> Enum.reverse()

      assert @default_limit = length(call_txis)
      assert ^call_txis = Enum.sort(call_txis)
      assert %{"data" => next_calls} = conn |> get(next) |> json_response(200)

      next_call_txis =
        next_calls |> Enum.map(fn %{"call_txi" => call_txi} -> call_txi end) |> Enum.reverse()

      assert @default_limit = length(next_call_txis)
      assert ^next_call_txis = Enum.sort(next_call_txis)
      assert Enum.at(call_txis, @default_limit - 1) >= Enum.at(next_call_txis, 0)
    end

    test "it get calls backwards with backward path without any filters", %{conn: conn} do
      assert %{"data" => calls, "next" => next} =
               conn |> get("/v2/contracts/calls") |> json_response(200)

      call_txis =
        calls
        |> Enum.map(fn %{"call_txi" => call_txi} -> call_txi end)
        |> Enum.reverse()

      assert @default_limit = length(call_txis)
      assert ^call_txis = Enum.sort(call_txis)
      assert %{"data" => next_calls} = conn |> get(next) |> json_response(200)

      next_call_txis =
        next_calls |> Enum.map(fn %{"call_txi" => call_txi} -> call_txi end) |> Enum.reverse()

      assert @default_limit = length(next_call_txis)
      assert ^next_call_txis = Enum.sort(next_call_txis)
      assert Enum.at(call_txis, @default_limit - 1) >= Enum.at(next_call_txis, 0)
    end

    test "is get calls forward without any filters", %{conn: conn} do
      assert %{"data" => calls, "next" => next} =
               conn
               |> get("/v2/contracts/calls", direction: "forward")
               |> json_response(200)

      call_txis = Enum.map(calls, fn %{"call_txi" => call_txi} -> call_txi end)

      assert @default_limit = length(call_txis)
      assert ^call_txis = Enum.sort(call_txis)
      assert %{"data" => next_calls} = conn |> get(next) |> json_response(200)

      next_call_txis = Enum.map(next_calls, fn %{"call_txi" => call_txi} -> call_txi end)

      assert @default_limit = length(next_call_txis)
      assert ^next_call_txis = Enum.sort(next_call_txis)
      assert Enum.at(call_txis, @default_limit - 1) <= Enum.at(next_call_txis, 0)
    end

    test "it gets calls forward belonging to a contract", %{conn: conn} do
      contract_id = "ct_2uJthb5s1D8c8F8ZYMAZ6LYGWno5ubFnrmkkHLE1FBzN3JruQw"

      assert %{"data" => calls, "next" => next} =
               conn
               |> get("/v2/contracts/calls", direction: "forward", contract_id: contract_id)
               |> json_response(200)

      create_txis = Enum.map(calls, fn %{"contract_txi" => create_txi} -> create_txi end)

      assert @default_limit = length(create_txis)
      assert ^create_txis = Enum.sort(create_txis)
      assert %{"internal_tx" => %{"query" => query_b64}} = Enum.at(calls, 2)
      assert {:ok, _query} = Base.decode64(query_b64)

      %{"data" => next_calls} = conn |> get(next) |> json_response(200)

      next_create_txis =
        Enum.map(next_calls, fn %{"contract_txi" => create_txi} -> create_txi end)

      assert @default_limit = length(next_create_txis)
      assert ^next_create_txis = Enum.sort(next_create_txis)
      assert Enum.at(create_txis, @default_limit - 1) <= Enum.at(next_create_txis, 0)
    end

    test "it gets calls forward filtered by a function name prefix", %{conn: conn} do
      fname_prefix = "Oracle"

      assert %{"data" => calls, "next" => next} =
               conn
               |> get("/v2/contracts/calls", direction: "forward", function: fname_prefix)
               |> json_response(200)

      fnames = Enum.map(calls, fn %{"function" => fname} -> fname end)

      assert @default_limit = length(fnames)
      assert ^fnames = Enum.sort(fnames)

      %{"data" => next_calls} = conn |> get(next) |> json_response(200)

      next_fnames = Enum.map(next_calls, fn %{"function" => fname} -> fname end)

      assert @default_limit = length(next_fnames)
      assert ^next_fnames = Enum.sort(next_fnames)
      assert Enum.at(fnames, @default_limit - 1) <= Enum.at(next_fnames, 0)
    end

    test "it gets calls forward filtered by recipient_id", %{conn: conn} do
      recipient_id = "ak_23bfFKQ1vuLeMxyJuCrMHiaGg5wc7bAobKNuDadf8tVZUisKWs"

      assert %{"data" => calls, "next" => next} =
               conn
               |> get("/v2/contracts/calls", direction: "forward", recipient_id: recipient_id)
               |> json_response(200)

      call_txi_local_idxs =
        Enum.map(calls, fn %{"call_txi" => call_txi, "local_idx" => local_idx} ->
          {call_txi, local_idx}
        end)

      assert @default_limit = length(call_txi_local_idxs)
      assert ^call_txi_local_idxs = Enum.sort(call_txi_local_idxs)
      assert Enum.all?(calls, &match?(%{"internal_tx" => %{"recipient_id" => ^recipient_id}}, &1))

      %{"data" => next_calls} = conn |> get(next) |> json_response(200)

      next_call_txi_local_idxs =
        Enum.map(next_calls, fn %{"call_txi" => call_txi, "local_idx" => local_idx} ->
          {call_txi, local_idx}
        end)

      assert @default_limit = length(next_call_txi_local_idxs)
      assert ^next_call_txi_local_idxs = Enum.sort(next_call_txi_local_idxs)

      assert Enum.at(call_txi_local_idxs, @default_limit - 1) <=
               Enum.at(next_call_txi_local_idxs, 0)
    end

    test "it gets calls filtered by recipient_id and contract_id", %{conn: conn} do
      contract_id = "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"
      recipient_id = "ak_23bfFKQ1vuLeMxyJuCrMHiaGg5wc7bAobKNuDadf8tVZUisKWs"

      assert %{"data" => calls, "next" => next} =
               conn
               |> get("/v2/contracts/calls", direction: "forward", recipient_id: recipient_id)
               |> json_response(200)

      call_txi_local_idxs =
        Enum.map(calls, fn %{"call_txi" => call_txi, "local_idx" => local_idx} ->
          {call_txi, local_idx}
        end)

      assert @default_limit = length(call_txi_local_idxs)
      assert ^call_txi_local_idxs = Enum.sort(call_txi_local_idxs)
      assert Enum.all?(calls, &match?(%{"internal_tx" => %{"recipient_id" => ^recipient_id}}, &1))
      assert Enum.all?(calls, &match?(%{"contract_id" => ^contract_id}, &1))

      %{"data" => next_calls} = conn |> get(next) |> json_response(200)

      next_call_txi_local_idxs =
        Enum.map(next_calls, fn %{"call_txi" => call_txi, "local_idx" => local_idx} ->
          {call_txi, local_idx}
        end)

      assert @default_limit = length(next_call_txi_local_idxs)
      assert ^next_call_txi_local_idxs = Enum.sort(next_call_txi_local_idxs)

      assert Enum.at(call_txi_local_idxs, @default_limit - 1) <=
               Enum.at(next_call_txi_local_idxs, 0)
    end

    test "it gets calls from the special contracts created by hard-forks", %{conn: conn} do
      contract_id = "ct_eJhrbPPS4V97VLKEVbSCJFpdA4uyXiZujQyLqMFoYV88TzDe6"

      assert %{"data" => calls, "next" => next} =
               conn
               |> get("/v2/contracts/calls", direction: "forward", contract_id: contract_id)
               |> json_response(200)

      call_txi_local_idxs =
        Enum.map(calls, fn %{"call_txi" => call_txi, "local_idx" => local_idx} ->
          {call_txi, local_idx}
        end)

      assert @default_limit = length(call_txi_local_idxs)
      assert ^call_txi_local_idxs = Enum.sort(call_txi_local_idxs)
      assert Enum.all?(calls, &match?(%{"contract_id" => ^contract_id}, &1))

      %{"data" => next_calls} = conn |> get(next) |> json_response(200)

      next_call_txi_local_idxs =
        Enum.map(next_calls, fn %{"call_txi" => call_txi, "local_idx" => local_idx} ->
          {call_txi, local_idx}
        end)

      assert @default_limit = length(next_call_txi_local_idxs)
      assert ^next_call_txi_local_idxs = Enum.sort(next_call_txi_local_idxs)

      assert Enum.at(call_txi_local_idxs, @default_limit - 1) <=
               Enum.at(next_call_txi_local_idxs, 0)
    end
  end
end
