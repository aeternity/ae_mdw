defmodule Devmode.AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag :devmode

  alias AeMdw.DevmodeHelpers
  alias AeMdw.Sync.Watcher

  setup_all do
    Watcher.start_sync()
    Process.sleep(2_000)
  end

  describe "tx" do
    test "it gets transactions in forwards order", %{conn: conn} do
      %{"accounts" => [sender_address, recipient_address]} = DevmodeHelpers.output()

      assert %{"data" => [tx]} =
               conn
               |> get("/v2/txs", direction: "forward", limit: 1)
               |> json_response(200)

      assert %{"tx" => %{"sender_id" => ^sender_address, "recipient_id" => ^recipient_address}} =
               tx
    end
  end
end
