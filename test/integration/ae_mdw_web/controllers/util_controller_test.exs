defmodule Integration.AeMdwWeb.UtilControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil

  require Model

  @moduletag :integration

  describe "status" do
    test "get middleware status", %{conn: conn} do
      state = State.new()
      {:ok, top_kb} = :aec_chain.top_key_block()
      {_app, _desc, node_vsn} = Application.started_applications() |> List.keyfind(:aecore, 0)
      node_height = :aec_blocks.height(top_kb)
      {:ok, mdw_tx_index} = DbUtil.last_txi(state)

      last_migration =
        case Database.last_key(Model.Migrations) do
          {:ok, version} -> version
          :none -> nil
        end

      mdw_height = State.mem_state() |> DbUtil.synced_height()

      conn = get(conn, "/status")

      node_version = to_string(node_vsn)
      mdw_version = AeMdw.MixProject.project()[:version]
      mdw_revision = :persistent_term.get({:ae_mdw, :build_revision})
      mdw_synced = node_height == mdw_height

      assert %{
               "mdw_last_migration" => ^last_migration,
               "mdw_version" => ^mdw_version,
               "mdw_revision" => ^mdw_revision,
               "mdw_height" => ^mdw_height,
               "mdw_tx_index" => ^mdw_tx_index,
               "mdw_synced" => ^mdw_synced,
               "mdw_async_tasks" => async_tasks_map,
               "node_version" => ^node_version,
               "node_height" => ^node_height,
               "node_progress" => 100.0,
               "node_syncing" => false
             } = Map.drop(json_response(conn, 200), ["node_revision", "mdw_syncing"])

      assert %{"producer_buffer" => producer_buffer, "total_pending" => total_pending} =
               async_tasks_map

      assert is_integer(producer_buffer) and is_integer(total_pending)
    end
  end

  describe "static_file" do
    test "gets v1/v2/v3 swagger files from priv directory", %{conn: conn} do
      assert %{"paths" => _paths, "definitions" => _definitions} =
               conn
               |> get("/api")
               |> response(200)
               |> Jason.decode!()

      assert %{"paths" => _paths, "components" => _components} =
               conn
               |> get("/v2/api")
               |> response(200)
               |> Jason.decode!()

      assert %{} =
               conn
               |> get("/v3/api")
               |> response(200)
               |> Jason.decode!()
    end
  end
end
