defmodule AeMdwWeb.UtilControllerTest do
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store

  use AeMdwWeb.ConnCase

  require Model

  describe "static_file" do
    test "gets v1/v2 swagger files from priv directory", %{conn: conn} do
      assert <<"{", _rest::binary>> =
               conn
               |> get("/api")
               |> response(200)

      assert <<"{", _rest::binary>> =
               conn
               |> get("/v2/api")
               |> response(200)
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
end
