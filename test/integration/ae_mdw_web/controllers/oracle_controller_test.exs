defmodule Integration.AeMdwWeb.OracleControllerTest do
  use AeMdwWeb.ConnCase

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Validate
  alias AeMdw.Db.{Oracle, Format}
  alias AeMdwWeb.{OracleController, TestUtil}
  alias AeMdwWeb.Continuation, as: Cont
  alias AeMdw.Error.Input, as: ErrInput

  import AeMdwWeb.Util

  @moduletag :integration

  @default_limit 10

  describe "oracle" do
    test "get oracle information for given oracle id", %{conn: conn} do
      id = "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM"
      conn = get(conn, "/oracle/#{id}")

      assert json_response(conn, 200) ==
               TestUtil.handle_input(fn ->
                 id
                 |> Validate.id!([:oracle_pubkey])
                 |> get_oracle(expand?(conn.params))
               end)
    end

    test "get oracle information for given oracle id with expand parameter", %{conn: conn} do
      id = "ok_2TASQ4QZv584D2ZP7cZxT6sk1L1UyqbWumnWM4g1azGi1qqcR5"
      conn = get(conn, "/oracle/#{id}?expand")

      assert json_response(conn, 200) |> Jason.encode!() ==
               TestUtil.handle_input(fn ->
                 id
                 |> Validate.id!([:oracle_pubkey])
                 |> get_oracle(expand?(conn.params))
                 |> Jason.encode!()
               end)
    end

    test "renders error when oracle id is invalid", %{conn: conn} do
      id = "invalid_oracle_id"
      conn = get(conn, "/oracle/#{id}")

      assert json_response(conn, 400) == %{"error" => "invalid id: #{id}"}
    end
  end

  describe "oracles" do
    test "get all oracles with default direction=backward and default limit", %{conn: conn} do
      conn = get(conn, "/oracles")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :oracles, %{}, conn.assigns.scope, 0},
          @default_limit
        )

      assert Enum.count(response["data"]) == @default_limit
      assert response["data"] == data

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :oracles, %{}, conn_next.assigns.scope, @default_limit},
          @default_limit
        )

      assert Enum.count(response_next["data"]) == @default_limit
      assert response_next["data"] == next_data
    end

    test "get all oracles with direction=forward and limit=3", %{conn: conn} do
      direction = "forward"
      limit = 3
      conn = get(conn, "/oracles?direction=#{direction}&limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :oracles, %{"direction" => [direction]}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert response["data"] == data

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :oracles, %{"direction" => [direction]}, conn_next.assigns.scope,
           limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert response_next["data"] == next_data
    end

    test "get all oracles with limit=7 and expand parameter ", %{conn: conn} do
      limit = 7
      conn = get(conn, "/oracles?limit=#{limit}&expand")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :oracles, %{"expand" => [nil]}, conn.assigns.scope, 0},
          limit
        )

      assert ^limit = Enum.count(response["data"])
      assert response["data"] |> Jason.encode!() == data |> Jason.encode!()

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :oracles, %{"expand" => [nil]}, conn_next.assigns.scope, limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert response_next["data"] |> Jason.encode!() == next_data |> Jason.encode!()
    end

    test "renders error when direction is invalid", %{conn: conn} do
      direction = "invalid"
      conn = get(conn, "/oracles?direction=#{direction}")

      assert json_response(conn, 400) == %{"error" => "invalid query: direction=#{direction}"}
    end

    test "renders error when limit is invalid", %{conn: conn} do
      limit = "invalid"
      conn = get(conn, "/oracles?limit=#{limit}")

      assert json_response(conn, 400) == %{"error" => "invalid limit: #{limit}"}
    end

    test "renders error when limit is to large", %{conn: conn} do
      limit = 10_000
      conn = get(conn, "/oracles?limit=#{limit}")

      assert json_response(conn, 400) == %{"error" => "limit too large: #{limit}"}
    end
  end

  describe "inactive_oracles" do
    test "get inactive oracles with default direction=backward and default limit", %{conn: conn} do
      conn = get(conn, "/oracles/inactive")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :inactive_oracles, %{}, conn.assigns.scope, 0},
          @default_limit
        )

      assert Enum.count(response["data"]) == @default_limit
      assert response["data"] == data

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :inactive_oracles, %{}, conn_next.assigns.scope, @default_limit},
          @default_limit
        )

      assert Enum.count(response_next["data"]) <= @default_limit
      assert response_next["data"] == next_data
    end

    test "get inactive oracles with direction=forward and limit=5", %{conn: conn} do
      direction = "forward"
      limit = 5
      conn = get(conn, "/oracles/inactive?direction=#{direction}&limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :inactive_oracles, %{"direction" => [direction]}, conn.assigns.scope,
           0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert response["data"] == data

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :inactive_oracles, %{"direction" => [direction]},
           conn_next.assigns.scope, limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert response_next["data"] == next_data
    end

    test "get inactive oracles with limit=1 and expand parameter ", %{conn: conn} do
      limit = 1
      conn = get(conn, "/oracles/inactive?limit=#{limit}&expand")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :inactive_oracles, %{"expand" => [nil]}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert response["data"] |> Jason.encode!() == data |> Jason.encode!()

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :inactive_oracles, %{"expand" => [nil]}, conn_next.assigns.scope,
           limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert response_next["data"] |> Jason.encode!() == next_data |> Jason.encode!()
    end

    test "renders error when direction is invalid", %{conn: conn} do
      direction = "invalid"
      conn = get(conn, "/oracles/inactive?direction=#{direction}")

      assert json_response(conn, 400) == %{"error" => "invalid query: direction=#{direction}"}
    end

    test "renders error when limit is invalid", %{conn: conn} do
      limit = "invalid"
      conn = get(conn, "/oracles/inactive?limit=#{limit}")

      assert json_response(conn, 400) == %{"error" => "invalid limit: #{limit}"}
    end

    test "renders error when limit is to large", %{conn: conn} do
      limit = 10_000
      conn = get(conn, "/oracles/inactive?limit=#{limit}")

      assert json_response(conn, 400) == %{"error" => "limit too large: #{limit}"}
    end
  end

  describe "active_oracles" do
    test "get active oracles with default direction=backward and limit=1", %{conn: conn} do
      limit = 1
      conn = get(conn, "/oracles/active?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :active_oracles, %{}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert response["data"] == data

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :active_oracles, %{}, conn_next.assigns.scope, limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert response_next["data"] == next_data
    end

    test "get active oracles with direction=forward and limit=1", %{conn: conn} do
      direction = "forward"
      limit = 1
      conn = get(conn, "/oracles/active?direction=#{direction}&limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :active_oracles, %{"direction" => [direction]}, conn.assigns.scope,
           0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert response["data"] == data

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :active_oracles, %{"direction" => [direction]},
           conn_next.assigns.scope, limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert response_next["data"] == next_data
    end

    test "get active oracles with limit=1 and expand parameter ", %{conn: conn} do
      limit = 1
      conn = get(conn, "/oracles/active?limit=#{limit}&expand")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :active_oracles, %{"expand" => [nil]}, conn.assigns.scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert response["data"] |> Jason.encode!() == data |> Jason.encode!()

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :active_oracles, %{"expand" => [nil]}, conn_next.assigns.scope,
           limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert response_next["data"] |> Jason.encode!() == next_data |> Jason.encode!()
    end

    test "renders error when direction is invalid", %{conn: conn} do
      direction = "invalid"
      conn = get(conn, "/oracles/active?direction=#{direction}")

      assert json_response(conn, 400) == %{"error" => "invalid query: direction=#{direction}"}
    end

    test "renders error when limit is invalid", %{conn: conn} do
      limit = "invalid"
      conn = get(conn, "/oracles/active?limit=#{limit}")

      assert json_response(conn, 400) == %{"error" => "invalid limit: #{limit}"}
    end

    test "renders error when limit is to large", %{conn: conn} do
      limit = 10_000
      conn = get(conn, "/oracles/active?limit=#{limit}")

      assert json_response(conn, 400) == %{"error" => "limit too large: #{limit}"}
    end
  end

  defp get_oracle(pubkey, expand?) do
    case Oracle.locate(pubkey) do
      {m_oracle, source} -> Format.to_map(m_oracle, source, expand?)
      nil -> raise ErrInput.NotFound, value: Enc.encode(:oracle_pubkey, pubkey)
    end
  end
end
