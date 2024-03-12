defmodule AeMdwWeb.Helpers.JSONHelperTest do
  use AeMdwWeb.ConnCase

  alias AeMdwWeb.Helpers.JSONHelper
  alias Plug.Conn

  describe "format_json/2" do
    test "when no int-as-string query param, it returns same JSON output", %{conn: conn} do
      assert [%{"a" => 1}] =
               conn
               |> JSONHelper.format_json([%{a: 1}])
               |> json_response(200)
    end

    test "when int-as-string=true query param, it returns output with ints as strings", %{
      conn: conn
    } do
      assert [%{"a" => "1"}] =
               conn
               |> Conn.assign(:int_as_string, true)
               |> JSONHelper.format_json([%{a: 1}])
               |> json_response(200)
    end
  end
end
