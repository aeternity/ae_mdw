defmodule AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase, async: false

  describe "txs" do
    test "it returns 400 when no direction specified", %{conn: conn} do
      assert %{"error" => "no such route"} = conn |> get("/txs") |> json_response(400)
    end
  end
end
