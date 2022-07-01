defmodule Integration.AeMdwWeb.UtilControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil

  @moduletag :integration

  describe "status" do
    test "get middleware status", %{conn: conn} do
      state = State.new()
      {:ok, top_kb} = :aec_chain.top_key_block()
      {_, _, node_vsn} = Application.started_applications() |> List.keyfind(:aecore, 0)
      node_height = :aec_blocks.height(top_kb)
      mdw_tx_index = DbUtil.last_txi(state)
      mdw_height = State.mem_state() |> DbUtil.synced_height()

      conn = get(conn, "/status")

      node_version = to_string(node_vsn)
      mdw_version = AeMdw.MixProject.project()[:version]
      mdw_revision = :persistent_term.get({:ae_mdw, :build_revision})
      mdw_synced = node_height == mdw_height

      assert %{
               "mdw_version" => ^mdw_version,
               "mdw_revision" => ^mdw_revision,
               "node_version" => ^node_version,
               "mdw_height" => ^mdw_height,
               "node_height" => ^node_height,
               "mdw_tx_index" => ^mdw_tx_index,
               "mdw_synced" => ^mdw_synced,
               "mdw_async_tasks" => async_tasks_map,
               "node_progress" => 100.0,
               "node_syncing" => false
             } = Map.drop(json_response(conn, 200), ["node_revision", "mdw_syncing"])

      assert %{"producer_buffer" => producer_buffer, "total_pending" => total_pending} =
               async_tasks_map

      assert is_integer(producer_buffer) and is_integer(total_pending)
    end
  end
end
