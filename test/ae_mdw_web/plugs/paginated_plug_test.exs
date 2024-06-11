defmodule AeMdwWeb.Plugs.PaginatedPlugTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias Plug.Conn

  require Model

  describe "call/2" do
    test "it builds pagination based on direction, limit, rev params", %{conn: conn} do
      store = empty_store()

      assert %{pagination: {:backward, false, 10, false}} =
               conn
               |> with_store(store)
               |> put_query(%{})
               |> PaginatedPlug.call([])
               |> get_assigns()

      assert %{pagination: {:forward, false, 20, false}} =
               conn
               |> with_store(store)
               |> put_query(%{"limit" => "20", "direction" => "forward"})
               |> PaginatedPlug.call([])
               |> get_assigns()

      assert %{"error" => "invalid direction: foo"} =
               conn
               |> with_store(store)
               |> put_query(%{"limit" => "20", "direction" => "foo"})
               |> PaginatedPlug.call([])
               |> json_response(400)

      assert %{pagination: {:backward, true, 9, false}} =
               conn
               |> with_store(store)
               |> put_query(%{"limit" => "9", "rev" => "1"})
               |> PaginatedPlug.call([])
               |> get_assigns()

      assert %{"error" => "invalid limit: 0"} =
               conn
               |> with_store(store)
               |> put_query(%{"limit" => "0"})
               |> PaginatedPlug.call([])
               |> json_response(400)

      assert %{pagination: {:backward, false, 10, true}} =
               conn
               |> with_store(store)
               |> put_query(%{"cursor" => "11"})
               |> PaginatedPlug.call([])
               |> get_assigns()
    end

    test "it parses the scope/range/scope_type", %{conn: conn} do
      store =
        empty_store()
        |> Store.put(
          Model.Time,
          Model.time(index: {30 |> DateTime.from_unix!() |> DateTime.to_unix(:millisecond), 1})
        )
        |> Store.put(
          Model.Time,
          Model.time(index: {50 |> DateTime.from_unix!() |> DateTime.to_unix(:millisecond), 2})
        )

      assert %{pagination: {:forward, _is_rev?, _limit, _has_cursor?}, scope: {:gen, 10..20}} =
               conn
               |> with_store(store)
               |> put_query(%{"scope_type" => "gen", "range" => "10-20"})
               |> PaginatedPlug.call([])
               |> get_assigns()

      assert %{pagination: {:forward, _is_rev?, _limit, _has_cursor?}, scope: {:gen, 10..20}} =
               conn
               |> with_store(store)
               |> put_query(%{"scope" => "gen:10-20"})
               |> PaginatedPlug.call([])
               |> get_assigns()

      assert %{pagination: {:backward, _is_rev?, _limit, _has_cursor?}, scope: {:gen, 10..20}} =
               conn
               |> with_store(store)
               |> put_query(%{"scope" => "gen:20-10"})
               |> PaginatedPlug.call([])
               |> get_assigns()

      assert %{pagination: {:backward, _is_rev?, _limit, _has_cursor?}, scope: {:gen, 30..30}} =
               conn
               |> with_store(store)
               |> put_query(%{"scope" => "gen:30"})
               |> PaginatedPlug.call([])
               |> get_assigns()

      assert %{pagination: {:forward, _is_rev?, _limit, _has_cursor?}, scope: {:gen, 30..30}} =
               conn
               |> with_store(store)
               |> put_query(%{"scope" => "gen:30-30", "direction" => "forward"})
               |> PaginatedPlug.call([])
               |> get_assigns()

      assert %{pagination: {:forward, _is_rev?, _limit, _has_cursor?}, scope: {:txi, 1..2}} =
               conn
               |> with_store(store)
               |> put_query(%{"scope" => "time:30-50", "direction" => "forward"})
               |> PaginatedPlug.call([])
               |> get_assigns()

      # when the range is invalid, default to impossible txi range
      assert %{pagination: {:forward, _is_rev?, _limit, _has_cursor?}, scope: {:txi, -1..-1}} =
               conn
               |> with_store(store)
               |> put_query(%{"scope" => "time:1-2", "direction" => "forward"})
               |> PaginatedPlug.call([])
               |> get_assigns()

      assert %{"error" => "invalid scope: asdf"} =
               conn
               |> with_store(store)
               |> put_query(%{"scope" => "asdf"})
               |> PaginatedPlug.call([])
               |> json_response(400)

      assert %{"error" => "invalid range: asdf"} =
               conn
               |> with_store(store)
               |> put_query(%{"range" => "asdf"})
               |> PaginatedPlug.call([])
               |> json_response(400)

      assert %{"error" => "invalid scope: foo"} =
               conn
               |> with_store(store)
               |> put_query(%{"range" => "10-20", "scope_type" => "foo"})
               |> PaginatedPlug.call([])
               |> json_response(400)
    end
  end

  defp put_query(conn, query), do: %Conn{conn | params: query, query_params: query}

  defp get_assigns(%Conn{assigns: assigns}), do: assigns
end
