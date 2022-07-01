defmodule AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase, async: false

  import Mock

  alias AeMdw.Db.Util

  describe "txs" do
    test "it returns 400 when no direction specified", %{conn: conn} do
      with_mocks [
        {Util, [],
         [
           last_gen: fn _state -> 1_000 end
         ]}
      ] do
        assert %{"error" => "no such route"} = conn |> get("/txs") |> json_response(400)
      end
    end
  end

  describe "tx" do
    test "when tx not found, it returns 404", %{conn: conn} do
      tx_hash = "th_2TbTPmKFU31WNQKfBGe5b5JDF9sFdAY7qot1smnxjbsEiu7LNr"

      assert %{"error" => _error_msg} = conn |> get("/tx/#{tx_hash}") |> json_response(404)
    end
  end
end
