defmodule AeMdwWeb.NameControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Validate
  alias AeMdw.Db.{Format, Model, Name}
  alias AeMdwWeb.NameController
  alias AeMdwWeb.Continuation, as: Cont
  alias AeMdw.Error.Input, as: ErrInput

  @default_limit 10

  describe "active_names" do
    test "get active names with default limit", %{conn: conn} do
      conn = get(conn, "/names/active")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :active_names, %{}, conn.assigns.scope, 0},
          @default_limit
        )

      assert Enum.count(response["data"]) == @default_limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {NameController, :active_names, %{}, conn.assigns.scope, @default_limit},
          @default_limit
        )

      assert Enum.count(response_next["data"]) == @default_limit

      assert Jason.encode!(response_next["data"]) == Jason.encode!(next_data)
    end

    test "get active names with limit=4", %{conn: conn} do
      limit = 4
      conn = get(conn, "/names/active?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :active_names, %{}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) <= limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
    end

    test "get active names with parameters by=name, direction=forward and limit=3", %{conn: conn} do
      by = "name"
      direction = "forward"
      limit = 3
      conn = get(conn, "/names/active?by=#{by}&direction=#{direction}&limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :active_names, %{"by" => [by], "direction" => [direction]},
           conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) <= limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      conn = get(conn, "/names/active?by=#{by}")

      assert json_response(conn, 400) == %{"error" => "invalid query: by=#{by}"}
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      conn = get(conn, "/names/active?by=#{by}&direction=#{direction}")

      assert json_response(conn, 400) == %{"error" => "invalid query: direction=#{direction}"}
    end
  end

  describe "inactive_names" do
    test "get inactive names with default limit", %{conn: conn} do
      conn = get(conn, "/names/inactive")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :inactive_names, %{}, conn.assigns.scope, 0},
          @default_limit
        )

      assert Enum.count(response["data"]) <= @default_limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {NameController, :inactive_names, %{}, conn.assigns.scope, @default_limit},
          @default_limit
        )

      assert Enum.count(response_next["data"]) == @default_limit

      assert Jason.encode!(response_next["data"]) == Jason.encode!(next_data)
    end

    test "get inactive names with limit=6", %{conn: conn} do
      limit = 6
      conn = get(conn, "/names/inactive?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :inactive_names, %{}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) <= limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
    end

    test "get inactive names with parameters by=name, direction=forward and limit=4", %{
      conn: conn
    } do
      by = "name"
      direction = "forward"
      limit = 4
      conn = get(conn, "/names/inactive?by=#{by}&direction=#{direction}&limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :inactive_names, %{"by" => [by], "direction" => [direction]},
           conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) <= limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      conn = get(conn, "/names/inactive?by=#{by}")

      assert json_response(conn, 400) == %{"error" => "invalid query: by=#{by}"}
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      conn = get(conn, "/names/inactive?by=#{by}&direction=#{direction}")

      assert json_response(conn, 400) == %{"error" => "invalid query: direction=#{direction}"}
    end
  end

  describe "auctions" do
    test "get auctions with default limit", %{conn: conn} do
      conn = get(conn, "/names/auctions")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :auctions, %{}, conn.assigns.scope, 0},
          @default_limit
        )

      assert Enum.count(response["data"]) <= @default_limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
    end

    test "get auctions with limit=2", %{conn: conn} do
      limit = 2
      conn = get(conn, "/names/auctions?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :auctions, %{}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) <= limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
    end

    test "get auctions with parameters by=expiration, direction=forward and limit=3", %{
      conn: conn
    } do
      limit = 3
      by = "expiration"
      direction = "forward"
      conn = get(conn, "/names/auctions?by=#{by}&direction=#{direction}&limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :auctions, %{"by" => [by], "direction" => [direction]},
           conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) <= limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      conn = get(conn, "/names/auctions?by=#{by}")

      assert json_response(conn, 400) == %{"error" => "invalid query: by=#{by}"}
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      conn = get(conn, "/names/auctions?by=#{by}&direction=#{direction}")

      assert json_response(conn, 400) == %{"error" => "invalid query: direction=#{direction}"}
    end
  end

  describe "names" do
    test "get active and inactive names, except those in auction, with default limit", %{
      conn: conn
    } do
      conn = get(conn, "/names")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :names, %{}, conn.assigns.scope, 0},
          @default_limit
        )

      assert Enum.count(response["data"]) == @default_limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {NameController, :names, %{}, conn.assigns.scope, @default_limit},
          @default_limit
        )

      assert Enum.count(response_next["data"]) == @default_limit

      assert Jason.encode!(response_next["data"]) == Jason.encode!(next_data)
    end

    test "get active and inactive names, except those in auction, with limit=2", %{conn: conn} do
      limit = 2
      conn = get(conn, "/names?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :names, %{}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
    end

    test "get active and inactive names, except those in auction, with parameters by=name, direction=forward and limit=4",
         %{conn: conn} do
      limit = 4
      by = "name"
      direction = "forward"
      conn = get(conn, "/names?by=#{by}&direction=#{direction}&limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :names, %{"by" => [by]}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      conn = get(conn, "/names?by=#{by}")

      assert json_response(conn, 400) == %{"error" => "invalid query: by=#{by}"}
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      conn = get(conn, "/names?by=#{by}&direction=#{direction}")

      assert json_response(conn, 400) == %{"error" => "invalid query: direction=#{direction}"}
    end
  end

  describe "name" do
    test "get name info by name", %{conn: conn} do
      name = "wwwbeaconoidcom.chain"
      conn = get(conn, "/name/#{name}")

      assert json_response(conn, 200) |> Jason.encode!() ==
               handle_input(fn -> get_name(Validate.plain_name!(name)) end) |> Jason.encode!()
    end

    test "get name info by encoded hash ", %{conn: conn} do
      hash = "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj"
      conn = get(conn, "/name/#{hash}")

      assert json_response(conn, 200) |> Jason.encode!() ==
               handle_input(fn -> get_name(Validate.plain_name!(hash)) end) |> Jason.encode!()
    end

    test "renders error when no such name is present", %{conn: conn} do
      name = "no--such--name--in--the--chain.chain"
      conn = get(conn, "/name/#{name}")

      assert json_response(conn, 400) == %{
               "error" => handle_input(fn -> get_name(Validate.plain_name!(name)) end)
             }
    end
  end

  describe "pointers" do
    test "get pointers for valid given name", %{conn: conn} do
      id = "wwwbeaconoidcom.chain"
      conn = get(conn, "/name/pointers/#{id}")

      assert json_response(conn, 200) ==
               handle_input(fn -> get_poiters(Validate.plain_name!(id)) end)
    end

    test "renders error when the name is missing", %{conn: conn} do
      id = "no--such--name--in--the--chain.chain"
      conn = get(conn, "/name/pointers/#{id}")

      assert json_response(conn, 400) == %{
               "error" => handle_input(fn -> get_poiters(Validate.plain_name!(id)) end)
             }
    end
  end

  describe "pointees" do
    test "get pointees for valid public key", %{conn: conn} do
      id = "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
      conn = get(conn, "/name/pointees/#{id}")

      assert json_response(conn, 200) ==
               handle_input(fn -> get_pointees(Validate.name_id!(id)) end)
    end

    test "renders error when the key is invalid", %{conn: conn} do
      id = "ak_invalidkey"
      conn = get(conn, "/name/pointees/#{id}")

      assert json_response(conn, 400) ==
               %{
                 "error" =>
                   handle_input(fn ->
                     get_pointees(Validate.name_id!(id))
                   end)
               }
    end
  end

  ##########

  defp get_name(name) do
    with {info, source} <- Name.locate(name) do
      Format.to_map(info, source)
    else
      nil ->
        raise ErrInput.NotFound, value: name
    end
  end

  defp get_poiters(name) do
    with {m_name, Model.ActiveName} <- Name.locate(name) do
      Format.map_raw_values(Name.pointers(m_name), &Format.to_json/1)
    else
      {_, Model.InactiveName} ->
        raise ErrInput.Expired, value: name

      _ ->
        raise ErrInput.NotFound, value: name
    end
  end

  defp get_pointees(pubkey) do
    {active, inactive} = Name.pointees(pubkey)

    %{
      "active" => Format.map_raw_values(active, &Format.to_json/1),
      "inactive" => Format.map_raw_values(inactive, &Format.to_json/1)
    }
  end

  defp handle_input(f) do
    try do
      f.()
    rescue
      err in [ErrInput] ->
        err.message
    end
  end
end
