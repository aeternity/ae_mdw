defmodule AeMdwWeb.UtilControllerTest do
  use AeMdwWeb.ConnCase

  describe "status" do
    test "get middleware status", %{conn: conn} do
      {:ok, top_kb} = :aec_chain.top_key_block()
      {_, _, node_vsn} = Application.started_applications() |> List.keyfind(:aecore, 0)

      conn = get(conn, "/status")

      assert json_response(conn, 200) == %{
               "mdw_version" => AeMdw.MixProject.project()[:version],
               "node_version" => to_string(node_vsn),
               "mdw_height" => AeMdw.Db.Util.last_gen(),
               "node_height" => :aec_blocks.height(top_kb)
             }
    end
  end
end
