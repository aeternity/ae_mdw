defmodule AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase, async: false

  import Mock

  alias AeMdw.Db.Util

  describe "txs" do
    test "without scope returns 200 and response data", %{conn: conn} do
      with_mocks [
        {Util, [],
         [
           first_gen: fn -> 0 end,
           last_gen: fn -> 1_000 end
         ]}
      ] do
        assert %{"data" => []} = conn |> get("/txs") |> json_response(200)
      end
    end

    test "with direction returns 200 and response data", %{conn: conn} do
      with_mocks [
        {Util, [],
         [
           first_gen: fn -> 0 end,
           last_gen: fn -> 1_000 end
         ]}
      ] do
        assert %{"data" => []} = conn |> get("/txs?direction=forward") |> json_response(200)
      end
    end
  end
end
