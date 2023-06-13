defmodule AeMdwWeb.SwaggerForwardTest do
  use AeMdwWeb.ConnCase

  describe "index_v1" do
    test "renders the swagger_v1.yaml", %{conn: conn} do
      conn = get(conn, "/swagger")

      assert "/mdw" <> index_page =
               "/mdw/swagger/index.html?version=v1" = redirected_to(conn, 302)

      conn = Phoenix.ConnTest.build_conn() |> get(index_page)
      assert html_response(conn, 200) =~ "Aeternity Middleware"
    end
  end

  describe "index_v2" do
    test "renders the swagger_v2.yaml", %{conn: conn} do
      conn = get(conn, "/v2/swagger")

      assert "/mdw" <> index_page =
               "/mdw/swagger/index.html?version=v2" = redirected_to(conn, 302)

      conn = Phoenix.ConnTest.build_conn() |> get(index_page)
      assert html_response(conn, 200) =~ "Aeternity Middleware"
    end
  end
end
