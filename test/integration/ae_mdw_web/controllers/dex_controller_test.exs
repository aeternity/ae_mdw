defmodule Integration.AeMdwWeb.DexControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model

  require Model

  @moduletag :integration

  @default_limit 10
  @ae_token_id "ct_J3zBY8xxjsRr3QojETNw48Eb38fjvEuJKkQ6KzECvubvEcvCa"

  describe "debug_contract_swaps" do
    test "it lists all dex swaps ordered by txi", %{conn: conn} do
      assert %{"data" => dex_swaps, "next" => next} =
               conn |> get("/v3/debug/dex/#{@ae_token_id}/swaps") |> json_response(200)

      dex_txis =
        dex_swaps
        |> Enum.map(fn %{"tx_hash" => tx_hash} ->
          conn
          |> get("/v2/txs/#{tx_hash}")
          |> json_response(200)
          |> Map.fetch!("tx_index")
        end)
        |> Enum.reverse()

      assert @default_limit = length(dex_swaps)
      assert ^dex_txis = Enum.sort(dex_txis)

      assert %{"data" => next_dex_swaps, "prev" => prev_dex_swaps} =
               conn |> get(next) |> json_response(200)

      next_dex_txis =
        dex_swaps
        |> Enum.map(fn %{"tx_hash" => tx_hash} ->
          conn
          |> get("/v2/txs/#{tx_hash}")
          |> json_response(200)
          |> Map.fetch!("tx_index")
        end)
        |> Enum.reverse()

      assert @default_limit = length(next_dex_swaps)
      assert ^next_dex_txis = Enum.sort(next_dex_txis)
      assert Enum.at(dex_txis, @default_limit - 1) >= Enum.at(next_dex_txis, 0)

      assert %{"data" => ^dex_swaps} = conn |> get(prev_dex_swaps) |> json_response(200)
    end
  end
end
