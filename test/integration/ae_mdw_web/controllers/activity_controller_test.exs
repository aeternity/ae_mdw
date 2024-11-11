defmodule Integration.AeMdwWeb.ActivityControllerTest do
  use AeMdwWeb.ConnCase, async: false

  @moduletag :integration

  describe "account_activities" do
    test "by default, it gets all account events backwards", %{conn: conn} do
      account = "ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx"

      assert %{"data" => events, "next" => next_url} =
               conn
               |> get("/v3/accounts/#{account}/activities")
               |> json_response(200)

      heights = events |> Enum.map(&Map.fetch!(&1, "height")) |> Enum.reverse()

      assert ^heights = Enum.sort(heights)

      assert %{"data" => next_events} =
               conn
               |> get(next_url)
               |> json_response(200)

      next_heights = next_events |> Enum.map(&Map.fetch!(&1, "height")) |> Enum.reverse()

      assert List.last(heights) >= Enum.at(next_heights, 0)
    end

    test "when direction=forward it gets all account events forwards", %{conn: conn} do
      account = "ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx"
      from_height = 18_061
      to_height = 1_000_000

      assert %{"data" => [first_event | _rest] = events, "next" => next_url} =
               conn
               |> get("/v3/accounts/#{account}/activities",
                 direction: "forward",
                 scope: "gen:#{from_height}-#{to_height}"
               )
               |> json_response(200)

      assert Enum.all?(
               events,
               &match?(
                 %{"height" => height} when height >= from_height and height <= to_height,
                 &1
               )
             )

      assert %{"type" => "SpendTxEvent", "payload" => %{"tx" => tx}} = first_event
      assert %{"recipient_id" => ^account} = tx

      assert %{"prev" => prev_url, "data" => next_events} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert Enum.all?(
               next_events,
               &match?(
                 %{"height" => height} when height >= from_height and height <= to_height,
                 &1
               )
             )

      assert %{"data" => ^events} = conn |> get(prev_url) |> json_response(200)
    end

    test "when account is invalid", %{conn: conn} do
      invalid_account = "ak_foooo"
      error_msg = "invalid id: #{invalid_account}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/accounts/#{invalid_account}/activities")
               |> json_response(400)
    end

    test "it displays int transfers", %{conn: conn} do
      account = "ak_dArxCkAsk1mZB1L9CX3cdz1GDN4hN84L3Q8dMLHN4v8cU85TF"
      height = 665_679

      assert %{"data" => [first_event]} =
               conn
               |> get("/v3/accounts/#{account}/activities",
                 limit: 1,
                 direction: "forward",
                 scope: "gen:#{height}-#{height}"
               )
               |> json_response(200)

      assert %{
               "height" => ^height,
               "type" => "InternalTransferEvent",
               "payload" => %{"kind" => "reward_block", "ref_tx_hash" => nil}
             } = first_event
    end

    test "when txi-level and gen-level activities are present, it combines them properly", %{
      conn: conn
    } do
      account = "ak_dArxCkAsk1mZB1L9CX3cdz1GDN4hN84L3Q8dMLHN4v8cU85TF"
      height = 665_679

      assert %{"data" => events, "next" => next_url} =
               conn
               |> get("/v3/accounts/#{account}/activities",
                 limit: 10,
                 scope: "gen:#{height}-#{height}"
               )
               |> json_response(200)

      assert 10 = length(events)

      assert Enum.all?(
               events,
               &match?(
                 %{
                   "height" => ^height,
                   "type" => "SpendTxEvent",
                   "payload" => %{"tx" => %{"sender_id" => ^account}}
                 },
                 &1
               )
             )

      assert %{"prev" => prev_url, "data" => next_events, "next" => next_next_url} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert Enum.all?(next_events, &match?(%{"height" => ^height}, &1))
      assert 10 = length(next_events)

      assert Enum.all?(
               events,
               &match?(
                 %{
                   "height" => ^height,
                   "type" => "SpendTxEvent",
                   "payload" => %{"tx" => %{"sender_id" => ^account}}
                 },
                 &1
               )
             )

      assert %{"data" => ^events} = conn |> get(prev_url) |> json_response(200)

      assert %{"data" => next_next_events, "next" => nil} =
               conn
               |> get(next_next_url)
               |> json_response(200)

      assert 1 = length(next_next_events)

      assert [
               %{
                 "height" => ^height,
                 "type" => "InternalTransferEvent",
                 "payload" => %{"kind" => "reward_block", "ref_tx_hash" => nil}
               }
             ] = next_next_events
    end

    test "it gets hardfork transfer events", %{conn: conn} do
      account = "ak_1K5vpH1WEGSQnrSLdk1Y1fBBc48zA6xiijuaQQbUKgLhcHZ5J"

      assert %{"data" => events} =
               conn
               |> get("/v3/accounts/#{account}/activities", direction: "forward")
               |> json_response(200)

      heights = Enum.map(events, &Map.fetch!(&1, "height"))

      assert ^heights = Enum.sort(heights)

      assert [
               %{
                 "type" => "InternalTransferEvent",
                 "payload" => %{"kind" => "accounts_genesis", "amount" => _amount}
               }
               | _rest
             ] = events
    end

    test "it gets tx-based internal transfer events", %{conn: conn} do
      account = "ak_4HGhEdjeRtpsWzfSEJZnBKNmjgHALAifcBUey8EvRAdDfRsqc"
      height = 248_897
      limit = 100

      assert %{"data" => events} =
               conn
               |> get("/v3/accounts/#{account}/activities",
                 direction: "forward",
                 scope: "gen:#{height}-#{height}",
                 limit: limit
               )
               |> json_response(200)

      assert [
               %{
                 "type" => "InternalTransferEvent",
                 "payload" => %{"kind" => "reward_oracle", "amount" => _amount}
               }
             ] = Enum.filter(events, &match?(%{"type" => "InternalTransferEvent"}, &1))
    end

    test "it gets aex9 transfers where the account is involved", %{conn: conn} do
      account = "ak_2qTyjUbtE2LrLxh743JX2aL9jrR2fMpFrdaM45SDJ43USYFpv9"
      height = 418_912

      assert %{"data" => [_activity1, activity2]} =
               conn
               |> get("/v3/accounts/#{account}/activities",
                 direction: "forward",
                 scope: "gen:#{height}"
               )
               |> json_response(200)

      assert %{
               "block_hash" => "mh_5d1NZ5tpiZ5Wq61xBxNoUwA4PdFfjSJrCJWjL8upTYiD3WMpg",
               "height" => height,
               "payload" => %{
                 "amount" => 100_000_000_000_000_000_000,
                 "block_height" => height,
                 "contract_id" => "ct_taqHFzEWhDmwgddBYBL9ZsJTcSK2wX7MSS2VW3FTAMy2sUT4r",
                 "log_idx" => 0,
                 "micro_index" => 7,
                 "micro_time" => 1_619_241_678_856,
                 "recipient_id" => "ak_24h4GD5wdWmQ5sLFADdZYKjEREMujbTAup5THvthcnPikYozq3",
                 "sender_id" => "ak_2qTyjUbtE2LrLxh743JX2aL9jrR2fMpFrdaM45SDJ43USYFpv9",
                 "tx_hash" => "th_SmBJML6DNsELXw13zvStqpGfnF3ks4C98ZKXK9wdVgsEYmvio"
               },
               "type" => "Aex9TransferEvent"
             } = activity2
    end

    test "it gets aex141 transfers where the account is involved", %{conn: conn} do
      account = "ak_uTWegpfN6UjA4yz8X4ZVRi9xKEYeXHJDRZcRryTsRHAFoBpLa"
      height = 653_289

      assert %{"data" => [_activity1, _activity2, activity3]} =
               conn
               |> get("/v3/accounts/#{account}/activities",
                 direction: "forward",
                 scope: "gen:#{height}"
               )
               |> json_response(200)

      assert %{
               "block_hash" => "mh_2voSWMaC6hmhyCc8qZ7AxmenrK2CkqKeUg4bkFA8gcRTd4RwVB",
               "height" => ^height,
               "payload" => %{
                 "block_height" => ^height,
                 "contract_id" => "ct_2MFbjHcaFJXqLH9WrSZcX6EjbWKPhos1fv8nqXfPLoHMV1qVZz",
                 "log_idx" => 0,
                 "micro_index" => 125,
                 "micro_time" => 1_662_654_259_282,
                 "recipient_id" => "ak_uTWegpfN6UjA4yz8X4ZVRi9xKEYeXHJDRZcRryTsRHAFoBpLa",
                 "sender_id" => "ak_11111111111111111111111111111111273Yts",
                 "token_id" => 1,
                 "tx_hash" => "th_2FciwUNyT7WRGee35KnNMhuoLFSCyiquVLFP3kATjwrFJh4Cfh"
               },
               "type" => "Aex141TransferEvent"
             } = activity3
    end

    test "when filtering by aexn type, it gets aexn activities only", %{conn: conn} do
      account = "ak_uTWegpfN6UjA4yz8X4ZVRi9xKEYeXHJDRZcRryTsRHAFoBpLa"
      height = 653_289

      assert %{"data" => [activity3]} =
               conn
               |> get("/v3/accounts/#{account}/activities",
                 direction: "forward",
                 scope: "gen:#{height}",
                 type: "aexn"
               )
               |> json_response(200)

      assert %{
               "block_hash" => "mh_2voSWMaC6hmhyCc8qZ7AxmenrK2CkqKeUg4bkFA8gcRTd4RwVB",
               "height" => ^height,
               "payload" => %{
                 "block_height" => ^height,
                 "contract_id" => "ct_2MFbjHcaFJXqLH9WrSZcX6EjbWKPhos1fv8nqXfPLoHMV1qVZz",
                 "log_idx" => 0,
                 "micro_index" => 125,
                 "micro_time" => 1_662_654_259_282,
                 "recipient_id" => "ak_uTWegpfN6UjA4yz8X4ZVRi9xKEYeXHJDRZcRryTsRHAFoBpLa",
                 "sender_id" => "ak_11111111111111111111111111111111273Yts",
                 "token_id" => 1,
                 "tx_hash" => "th_2FciwUNyT7WRGee35KnNMhuoLFSCyiquVLFP3kATjwrFJh4Cfh"
               },
               "type" => "Aex141TransferEvent"
             } = activity3
    end

    test "it gets name claims transactions when scoping by name", %{conn: conn} do
      name_hash = "nm_J5KSXjEQe6JMwXbceBAbAEX5kY8cywHhfCRAHpS7szmN7cSGD"

      assert %{"data" => [_activity1, _activity2, activity3 | _rest]} =
               conn
               |> get("/v3/accounts/#{name_hash}/activities", direction: "forward")
               |> json_response(200)

      assert %{
               "block_hash" => "mh_t22ENuhbAACbBqVdRsJ4ren7NuSSqhZLyG8a64ViQjWf6CdYq",
               "height" => 187_920,
               "payload" => %{
                 "micro_time" => 1_577_286_869_583,
                 "source_tx_hash" => "th_2pCj4SPpkCeMo99ZK9hGQFcxzT52fy7t1qNDZTrbafexFrFTvP",
                 "source_tx_type" => "NameClaimTx",
                 "tx" => %{
                   "account_id" => "ak_kiePw8Fa92v26aKoZc2Cuk5115RPJrqx2zAjzjXVwWypcYha5",
                   "fee" => 162_000_000_000_000,
                   "name" => "cyber.chain",
                   "name_fee" => 110_000_000_000_000_000_000,
                   "name_salt" => 0,
                   "nonce" => 13,
                   "ttl" => 0
                 }
               },
               "type" => "NameClaimEvent"
             } = activity3
    end
  end
end
