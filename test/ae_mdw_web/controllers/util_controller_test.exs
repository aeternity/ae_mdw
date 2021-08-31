defmodule AeMdwWeb.UtilControllerTest do
  use AeMdwWeb.ConnCase

  describe "status" do
    @tag :integration
    test "get middleware status", %{conn: conn} do
      import AeMdw.Db.Util

      {:ok, top_kb} = :aec_chain.top_key_block()
      {_, _, node_vsn} = Application.started_applications() |> List.keyfind(:aecore, 0)
      node_height = :aec_blocks.height(top_kb)
      mdw_tx_index = last_txi()
      {:tx, _, _, {mdw_height, _}, _} = read_tx!(mdw_tx_index)

      conn = get(conn, "/status")

      assert Map.drop(json_response(conn, 200), ["node_revision", "mdw_syncing"]) == %{
               "mdw_version" => AeMdw.MixProject.project()[:version],
               "node_version" => to_string(node_vsn),
               "mdw_height" => mdw_height,
               "node_height" => node_height,
               "mdw_tx_index" => mdw_tx_index,
               "mdw_synced" => node_height == mdw_height + 1,
               "node_progress" => 100.0,
               "node_syncing" => false
             }
    end
  end
end
