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

      assert Enum.count(response["data"]) == limit
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

    test "renders error when the access is random ", %{conn: conn} do
      limit = 6
      page = 2
      conn = get(conn, "/oracles?limit=#{limit}&page=#{page}")

      assert json_response(conn, 400) == %{"error" => "random access not supported"}
    end
  end

  describe "oracles_v2" do
    test "it fetches inactive oracles going forwards", %{conn: conn} do
      assert %{
               "data" => [
                 %{"oracle" => "ok_2TASQ4QZv584D2ZP7cZxT6sk1L1UyqbWumnWM4g1azGi1qqcR5"},
                 %{"oracle" => "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM"},
                 %{"oracle" => "ok_g5vQK6beY3vsTJHH7KBusesyzq9WMdEYorF8VyvZURXTjLnxT"},
                 %{"oracle" => "ok_pANDBzM259a9UgZFeiCJyWjXSeRhqrBQ6UCBBeXfbCQyP33Tf"},
                 %{"oracle" => "ok_cnFq6NgPNXzcwtggcAYUuSNKrW6fhRfDgYJa9WoRe6mEXwpah"},
                 %{"oracle" => "ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"},
                 %{"oracle" => "ok_2yjZGhe1fooEnkoax6bJoDjV45DqaHXYLXWKafzaC9coLMJZy"},
                 %{"oracle" => "ok_2Ez3Y4gQ1USuNxmSJry5YomnqsF6YTVVVFXVasB3jTSgbroB4z"},
                 %{"oracle" => "ok_KMVEB7Dxjefsn1jJvKQPKYk3a28xkPgSNe5gnum46pcyogUze"},
                 %{
                   "active" => false,
                   "active_from" => 288_192,
                   "expire_height" => 288_692,
                   "extends" => [],
                   "format" => %{"query" => "querySpace", "response" => "responseSpec"},
                   "oracle" => "ok_LZCSBq98L2kV5svbgE65shnZwgZzg8hMh13v86LMXQ8HJ7Kpp",
                   "query_fee" => 2_000_000_000_000_000,
                   "register" => 13_689_244
                 }
               ],
               "next" =>
                 "/v2/oracles/inactive/forward?cursor=288707-ok_ceRESNanBZ9ddGKZ75JacWQvR6GJnGci3cqXqMSN8yXL2rpkW&limit=10"
             } =
               conn
               |> get("/v2/oracles/inactive/forward")
               |> json_response(200)
    end

    test "it fetches active oracles going backward", %{conn: conn} do
      assert %{"data" => oracles, "next" => _next} =
               conn
               |> get("/v2/oracles/active/backward")
               |> json_response(200)

      assert Enum.all?(oracles, fn %{"active" => is_active?} -> is_active? end)
    end

    ############################################################################
    ## BACKWARDS COMPAT TESTING (compare v2 with v2)
    ############################################################################
    test "get inactive oracles with default direction=backward and default limit", %{conn: conn} do
      conn = get(conn, "/v2/oracles/inactive")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data({OracleController, :inactive_oracles, %{}, :foo, 0}, @default_limit)

      assert Enum.count(response["data"]) == @default_limit
      assert response["data"] == data

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :inactive_oracles, %{}, :foo, @default_limit},
          @default_limit
        )

      assert Enum.count(response_next["data"]) <= @default_limit
      assert response_next["data"] == next_data
    end

    test "get inactive oracles with direction=forward and limit=5", %{conn: conn} do
      direction = "forward"
      limit = 5
      conn = get(conn, "/v2/oracles/inactive?direction=#{direction}&limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :inactive_oracles, %{"direction" => [direction]}, :foo, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert response["data"] == data

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :inactive_oracles, %{"direction" => [direction]}, :foo, limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert response_next["data"] == next_data
    end

    test "get active oracles with default direction=backward and limit=1", %{conn: conn} do
      limit = 1
      conn = get(conn, "/v2/oracles/active?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data({OracleController, :active_oracles, %{}, :foo, 0}, limit)

      assert Enum.count(response["data"]) == limit
      assert response["data"] == data

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data({OracleController, :active_oracles, %{}, :foo, limit}, limit)

      assert Enum.count(response_next["data"]) == limit
      assert response_next["data"] == next_data
    end

    test "get active oracles with direction=forward and limit=1", %{conn: conn} do
      direction = "forward"
      limit = 1
      conn = get(conn, "/v2/oracles/active?direction=#{direction}&limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {OracleController, :active_oracles, %{"direction" => [direction]}, :foo, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert response["data"] == data

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {OracleController, :active_oracles, %{"direction" => [direction]}, :foo, limit},
          limit
        )

      assert Enum.count(response_next["data"]) == limit
      assert response_next["data"] == next_data
    end

    ############################################################################
    ## END BACKWARDS COMPAT
    ############################################################################
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

    test "renders error when the access is random ", %{conn: conn} do
      limit = 2
      page = 3
      conn = get(conn, "/oracles/inactive?limit=#{limit}&page=#{page}")

      assert json_response(conn, 400) == %{"error" => "random access not supported"}
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

    test "renders error when the access is random ", %{conn: conn} do
      limit = 2
      page = 3
      conn = get(conn, "/oracles/active?limit=#{limit}&page=#{page}")

      assert json_response(conn, 400) == %{"error" => "random access not supported"}
    end
  end

  defp get_oracle(pubkey, expand?) do
    with {m_oracle, source} <- Oracle.locate(pubkey) do
      Format.to_map(m_oracle, source, expand?)
    else
      nil ->
        raise ErrInput.NotFound, value: Enc.encode(:oracle_pubkey, pubkey)
    end
  end
end
