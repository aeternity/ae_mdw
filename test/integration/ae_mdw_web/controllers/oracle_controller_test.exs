defmodule Integration.AeMdwWeb.OracleControllerTest do
  use AeMdwWeb.ConnCase

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Validate
  alias AeMdw.Db.{Oracle, Format}
  alias AeMdwWeb.TestUtil
  alias AeMdw.Error.Input, as: ErrInput

  import AeMdwWeb.Util

  @moduletag :integration

  @default_limit 10

  describe "oracle" do
    test "get oracle information for given oracle id", %{conn: conn} do
      id = "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM"
      conn = get(conn, "/oracles/#{id}")

      assert json_response(conn, 200) ==
               TestUtil.handle_input(fn ->
                 id
                 |> Validate.id!([:oracle_pubkey])
                 |> get_oracle(expand?(conn.params))
               end)
    end

    test "get oracle information for given oracle id with expand parameter", %{conn: conn} do
      id = "ok_2TASQ4QZv584D2ZP7cZxT6sk1L1UyqbWumnWM4g1azGi1qqcR5"
      conn = get(conn, "/v2/oracles/#{id}?expand")

      assert conn |> json_response(200) |> Jason.encode!() ==
               TestUtil.handle_input(fn ->
                 id
                 |> Validate.id!([:oracle_pubkey])
                 |> get_oracle(expand?(conn.params))
                 |> Jason.encode!()
               end)
    end

    test "renders error when oracle id is invalid", %{conn: conn} do
      id = "invalid_oracle_id"
      conn = get(conn, "/oracles/#{id}")

      assert json_response(conn, 400) == %{"error" => "invalid id: #{id}"}
    end

    test "it returns oracles registered through contract calls using Oracle.register", %{
      conn: conn
    } do
      assert %{"data" => [contract_call]} =
               conn
               |> get("/v2/contracts/calls/backward", function: "Oracle.register", limit: 1)
               |> json_response(200)

      assert %{
               "internal_tx" => %{
                 "oracle_id" => oracle_id,
                 "oracle_ttl" => %{"type" => "delta", "value" => ttl}
               },
               "height" => height
             } = contract_call

      expire = height + ttl

      assert %{"expire_height" => ^expire} =
               conn |> get("/oracle/#{oracle_id}") |> json_response(200)
    end
  end

  describe "oracles" do
    test "get all oracles with default direction=backward and default limit", %{conn: conn} do
      %{"data" => oracles, "next" => next} = conn |> get("/oracles") |> json_response(200)

      expirations =
        oracles
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert @default_limit = length(oracles)
      assert ^expirations = Enum.sort(expirations)

      %{"data" => next_oracles} = conn |> get(next) |> json_response(200)

      next_expirations =
        next_oracles
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert @default_limit = length(next_oracles)
      assert ^next_expirations = Enum.sort(next_expirations)
      assert Enum.at(expirations, @default_limit - 1) >= Enum.at(next_expirations, 0)
    end

    test "get all oracles with direction=forward and limit=3", %{conn: conn} do
      direction = "forward"
      limit = 3

      %{"data" => oracles, "next" => next} =
        conn |> get("/oracles", direction: direction, limit: limit) |> json_response(200)

      expirations = Enum.map(oracles, fn %{"expire_height" => expire_height} -> expire_height end)

      assert ^limit = length(oracles)
      assert ^expirations = Enum.sort(expirations)

      %{"data" => next_oracles} = conn |> get(next) |> json_response(200)

      next_expirations =
        Enum.map(oracles, fn %{"expire_height" => expire_height} -> expire_height end)

      assert ^limit = length(next_oracles)
      assert ^next_expirations = Enum.sort(next_expirations)
    end

    test "get all oracles with limit=7 and expand parameter ", %{conn: conn} do
      limit = 7

      %{"data" => oracles, "next" => next} =
        conn |> get("/v2/oracles", limit: limit, expand: true) |> json_response(200)

      assert ^limit = length(oracles)

      assert Enum.all?(oracles, fn %{"register" => register, "extends" => extends} ->
               is_map(register) and Enum.all?(extends, &is_map/1)
             end)

      %{"data" => next_oracles} = conn |> get(next) |> json_response(200)

      assert ^limit = length(next_oracles)

      assert Enum.all?(next_oracles, fn %{"register" => register, "extends" => extends} ->
               is_map(register) and Enum.all?(extends, &is_map/1)
             end)
    end

    test "renders error when direction is invalid", %{conn: conn} do
      direction = "invalid"
      error_msg = "invalid direction: #{direction}"

      %{"error" => ^error_msg} =
        conn |> get("/oracles", direction: direction) |> json_response(400)
    end

    test "renders error when limit is invalid", %{conn: conn} do
      limit = "invalid"
      conn = get(conn, "/oracles?limit=#{limit}")

      assert json_response(conn, 400) == %{"error" => "invalid limit: #{limit}"}
    end

    test "renders error when limit is to large", %{conn: conn} do
      limit = 10_000
      error_msg = "limit too large: #{limit}"

      assert %{"error" => ^error_msg} =
               conn |> get("/oracles", limit: limit) |> json_response(400)
    end

    test "it returns valid oracles on a given range", %{conn: conn} do
      first = 100_000
      last = 1_000_000

      assert %{"data" => data, "next" => next} =
               conn
               |> get("/oracles/gen/#{first}-#{last}")
               |> json_response(200)

      assert Enum.all?(data, fn %{"expire_height" => kbi} -> first <= kbi && kbi <= last end)
      assert @default_limit = length(data)

      assert %{"data" => data2} =
               conn
               |> get(next)
               |> json_response(200)

      assert @default_limit = length(data2)
      assert Enum.all?(data2, fn %{"expire_height" => kbi} -> first <= kbi && kbi <= last end)
    end

    test "it returns valid oracles on a given range in reverse", %{conn: conn} do
      first = 500_000
      last = 100_000

      assert %{"data" => data} =
               conn |> get("/oracles/gen/#{first}-#{last}") |> json_response(200)

      assert @default_limit = length(data)
      assert Enum.all?(data, fn %{"expire_height" => kbi} -> last <= kbi && kbi <= first end)

      kbis = data |> Enum.map(fn %{"expire_height" => kbi} -> kbi end) |> Enum.reverse()
      assert Enum.sort(kbis) == kbis
    end
  end

  describe "inactive_oracles" do
    test "get inactive oracles with default direction=backward and default limit", %{conn: conn} do
      assert %{"data" => oracles, "next" => next} =
               conn |> get("/oracles/inactive") |> json_response(200)

      expirations =
        oracles
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert @default_limit = length(oracles)
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_oracles} = conn |> get(next) |> json_response(200)

      next_expirations =
        next_oracles
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert @default_limit = length(next_oracles)
      assert ^next_expirations = Enum.sort(next_expirations)
      assert Enum.at(expirations, @default_limit - 1) >= Enum.at(next_expirations, 0)
    end

    test "get inactive oracles with direction=forward and limit=5", %{conn: conn} do
      direction = "forward"
      limit = 5

      assert %{"data" => oracles, "next" => next} =
               conn
               |> get("/oracles/inactive", direction: direction, limit: limit)
               |> json_response(200)

      expirations = Enum.map(oracles, fn %{"expire_height" => expire_height} -> expire_height end)

      assert ^limit = length(oracles)
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_oracles} = conn |> get(next) |> json_response(200)

      next_expirations =
        Enum.map(next_oracles, fn %{"expire_height" => expire_height} -> expire_height end)

      assert ^limit = length(next_oracles)
      assert ^next_expirations = Enum.sort(next_expirations)
      assert Enum.at(expirations, limit - 1) <= Enum.at(next_expirations, 0)
    end

    test "get inactive oracles with limit=1 and expand parameter ", %{conn: conn} do
      limit = 1

      assert %{"data" => oracles, "next" => next} =
               conn
               |> get("/oracles/inactive", limit: limit, expand: "true")
               |> json_response(200)

      assert ^limit = length(oracles)

      assert Enum.all?(oracles, fn %{"register" => register, "extends" => extends} ->
               is_map(register) and Enum.all?(extends, &is_map/1)
             end)

      assert %{"data" => next_oracles} = conn |> get(next) |> json_response(200)

      assert ^limit = length(next_oracles)

      assert Enum.all?(next_oracles, fn %{"register" => register, "extends" => extends} ->
               is_map(register) and Enum.all?(extends, &is_map/1)
             end)
    end

    test "renders error when direction is invalid", %{conn: conn} do
      direction = "invalid"
      error_msg = "invalid direction: #{direction}"

      assert %{"error" => ^error_msg} =
               conn |> get("/oracles/inactive", direction: direction) |> json_response(400)
    end

    test "renders error when limit is invalid", %{conn: conn} do
      limit = "invalid"
      error_msg = "invalid limit: #{limit}"

      assert %{"error" => ^error_msg} =
               conn |> get("/oracles/inactive", limit: limit) |> json_response(400)
    end

    test "renders error when limit is to large", %{conn: conn} do
      limit = 10_000
      error_msg = "limit too large: #{limit}"

      assert %{"error" => ^error_msg} =
               conn |> get("/oracles/inactive?limit=#{limit}") |> json_response(400)
    end
  end

  describe "active_oracles" do
    test "get active oracles with default direction=backward and limit=1", %{conn: conn} do
      limit = 1

      assert %{"data" => oracles, "next" => next} =
               conn |> get("/oracles/inactive", limit: limit) |> json_response(200)

      expirations =
        oracles
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert ^limit = length(oracles)
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_oracles} = conn |> get(next) |> json_response(200)

      next_expirations =
        next_oracles
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert ^limit = length(next_oracles)
      assert ^next_expirations = Enum.sort(next_expirations)
      assert Enum.at(expirations, @default_limit - 1) >= Enum.at(next_expirations, 0)
    end

    test "get active oracles with direction=forward and limit=1", %{conn: conn} do
      direction = "forward"
      limit = 1

      assert %{"data" => oracles, "next" => next} =
               conn
               |> get("/oracles/inactive", limit: limit, direction: direction)
               |> json_response(200)

      expirations = Enum.map(oracles, fn %{"expire_height" => expire_height} -> expire_height end)

      assert ^limit = length(oracles)
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_oracles} = conn |> get(next) |> json_response(200)

      next_expirations =
        Enum.map(next_oracles, fn %{"expire_height" => expire_height} -> expire_height end)

      assert ^limit = length(next_oracles)
      assert ^next_expirations = Enum.sort(next_expirations)
      assert Enum.at(expirations, limit - 1) <= Enum.at(next_expirations, 0)
    end

    test "get active oracles with limit=1 and expand parameter ", %{conn: conn} do
      limit = 1

      assert %{"data" => oracles, "next" => next} =
               conn |> get("/oracles/inactive", limit: limit, expand: true) |> json_response(200)

      assert ^limit = length(oracles)

      assert Enum.all?(oracles, fn %{"register" => register, "extends" => extends} ->
               is_map(register) and Enum.all?(extends, &is_map/1)
             end)

      assert %{"data" => next_oracles} = conn |> get(next) |> json_response(200)

      assert ^limit = length(next_oracles)

      assert Enum.all?(next_oracles, fn %{"register" => register, "extends" => extends} ->
               is_map(register) and Enum.all?(extends, &is_map/1)
             end)
    end

    test "renders error when direction is invalid", %{conn: conn} do
      direction = "invalid"
      conn = get(conn, "/oracles/active?direction=#{direction}")

      assert json_response(conn, 400) == %{"error" => "invalid direction: #{direction}"}
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
