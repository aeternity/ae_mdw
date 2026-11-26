defmodule AeMdwWeb.UtilControllerTest do
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Sync.Server

  use AeMdwWeb.ConnCase

  import Mock

  require Model

  describe "static_file" do
    test "gets v1/v2 swagger files from priv directory", %{conn: conn} do
      resp = conn |> get("/api")
      assert response(resp, 200) =~ "{"
      assert response_content_type(resp, :json) =~ "application/json"

      resp2 = conn |> get("/v2/api")
      assert response(resp2, 200) =~ "{"
      assert response_content_type(resp2, :json) =~ "application/json"
    end
  end

  describe "status" do
    test "it returns last gen, regardless of transactions", %{conn: conn, store: store} do
      store =
        store
        |> Store.put(Model.DeltaStat, Model.delta_stat(index: 10))

      assert %{"mdw_height" => 10} =
               conn
               |> with_store(store)
               |> get("/status")
               |> json_response(200)
    end
  end

  describe "rollback" do
    test "answers 404 when the rollback isn't enabled", %{conn: conn} do
      with_mocks [{Server, [:passthrough], rollback: fn -> :ok end}] do
        assert %{"error" => "no such route"} =
                 conn |> get("/debug/rollback") |> json_response(404)

        assert_not_called(Server.rollback())
      end
    end

    test "rolls the db back when enabled", %{conn: conn} do
      enabled? = Application.fetch_env!(:ae_mdw, :enable_rollback)
      Application.put_env(:ae_mdw, :enable_rollback, true)
      on_exit(fn -> Application.put_env(:ae_mdw, :enable_rollback, enabled?) end)

      with_mocks [{Server, [:passthrough], rollback: fn -> :ok end}] do
        assert %{} == conn |> get("/debug/rollback") |> json_response(200)
        assert_called(Server.rollback())
      end
    end
  end
end
