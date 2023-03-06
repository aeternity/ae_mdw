defmodule AeMdwWeb.UtilControllerTest do
  use AeMdwWeb.ConnCase

  describe "static_file" do
    test "gets v1/v2 swagger files from priv directory", %{conn: conn} do
      assert <<"basePath: ", _rest::binary>> =
               conn
               |> get("/api")
               |> response(200)

      assert <<"basePath: ", _rest::binary>> =
               conn
               |> get("/v2/api")
               |> response(200)
    end
  end
end
