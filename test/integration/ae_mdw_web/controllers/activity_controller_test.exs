defmodule Integration.AeMdwWeb.ActivityControllerTest do
  use AeMdwWeb.ConnCase, async: false

  @moduletag :integration

  describe "account_activities" do
    test "by default, it gets all account events backwards", %{conn: conn} do
      account = "ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx"

      assert %{"data" => events, "next" => next_url} =
               conn
               |> get("/v2/accounts/#{account}/activities")
               |> json_response(200)

      heights = events |> Enum.map(&Map.fetch(&1, "height")) |> Enum.reverse()

      assert ^heights = Enum.sort(heights)

      assert %{"data" => next_events} =
               conn
               |> get(next_url)
               |> json_response(200)

      next_heights = next_events |> Enum.map(&Map.fetch(&1, "height")) |> Enum.reverse()

      assert List.last(heights) >= Enum.at(next_heights, 0)
    end

    test "when direction=forward it gets all account events forwards", %{conn: conn} do
      account = "ak_2nVdbZTBVTbAet8j2hQhLmfNm1N2WKoAGyL7abTAHF1wGMPjzx"
      from_height = 18_061
      to_height = 1_000_000

      assert %{"data" => [first_event | _rest] = events, "next" => next_url} =
               conn
               |> get("/v2/accounts/#{account}/activities",
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
               |> get("/v2/accounts/#{invalid_account}/activities")
               |> json_response(400)
    end

    test "it displays int transfers", %{conn: conn} do
      account = "ak_dArxCkAsk1mZB1L9CX3cdz1GDN4hN84L3Q8dMLHN4v8cU85TF"
      height = 665_679

      assert %{"data" => [first_event]} =
               conn
               |> get("/v2/accounts/#{account}/activities",
                 limit: 1,
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
               |> get("/v2/accounts/#{account}/activities",
                 limit: 10,
                 scope: "gen:#{height}-#{height}"
               )
               |> json_response(200)

      assert 10 = length(events)
      assert Enum.all?(events, &match?(%{"height" => ^height}, &1))

      assert %{"prev" => prev_url, "data" => next_events, "next" => next_next_url} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert Enum.all?(next_events, &match?(%{"height" => ^height}, &1))

      assert %{"data" => ^events} = conn |> get(prev_url) |> json_response(200)
    end
  end
end
