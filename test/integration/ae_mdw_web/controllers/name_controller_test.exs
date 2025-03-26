defmodule Integration.AeMdwWeb.NameControllerTest do
  use AeMdwWeb.ConnCase
  use Mneme

  alias :aeser_api_encoder, as: Enc

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.State
  alias AeMdw.Db.Util
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate
  alias AeMdw.TestUtil
  alias AeMdw.IntegrationUtil

  require Model

  @moduletag :integration

  @default_limit 10

  describe "active names" do
    test "it get active names backwards without any filters", %{conn: conn} do
      assert %{"data" => names, "next" => next} =
               conn |> get("/v3/names", state: "active") |> json_response(200)

      expirations =
        names
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert length(names) <= @default_limit
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_names, "prev" => prev_names} =
               conn |> get(next) |> json_response(200)

      if next do
        next_expirations =
          next_names
          |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
          |> Enum.reverse()

        assert length(next_names) <= @default_limit
        assert ^next_expirations = Enum.sort(next_expirations)
        assert Enum.at(expirations, @default_limit - 1) >= Enum.at(next_expirations, 0)

        assert %{"data" => ^names} = conn |> get(prev_names) |> json_response(200)
      end
    end

    test "it get active names backwards by default with by=expiration", %{conn: conn} do
      assert %{"data" => names, "next" => next} =
               conn |> get("/v3/names?by=expiration", state: "active") |> json_response(200)

      expirations =
        names
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert length(names) <= @default_limit
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_names, "prev" => prev_names} =
               conn |> get(next) |> json_response(200)

      if next do
        next_expirations =
          next_names
          |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
          |> Enum.reverse()

        assert length(next_names) <= @default_limit
        assert ^next_expirations = Enum.sort(next_expirations)
        assert Enum.at(expirations, @default_limit - 1) >= Enum.at(next_expirations, 0)

        assert %{"data" => ^names} = conn |> get(prev_names) |> json_response(200)
      end
    end

    test "get active names forward with limit=4", %{conn: conn} do
      limit = 4

      assert %{"data" => names, "next" => next} =
               conn
               |> get("/v3/names", state: "active", direction: "forward", limit: limit)
               |> json_response(200)

      expirations =
        Enum.map(names, fn %{"expire_height" => expire_height} -> expire_height end)

      assert length(names) <= limit
      assert ^expirations = Enum.sort(expirations)

      if next do
        assert %{"data" => next_names, "prev" => prev_names} =
                 conn |> get(next) |> json_response(200)

        next_expirations =
          Enum.map(next_names, fn %{"expire_height" => expire_height} ->
            expire_height
          end)

        assert length(next_names) <= 4
        assert ^next_expirations = Enum.sort(next_expirations)
        assert Enum.at(expirations, limit - 1) <= Enum.at(next_expirations, 0)

        assert %{"data" => ^names} = conn |> get(prev_names) |> json_response(200)
      end
    end

    test "get active names with parameters by=name, direction=forward and limit=3", %{conn: conn} do
      by = "name"
      direction = "forward"
      limit = 3

      assert %{"data" => names} =
               conn
               |> get("/v3/names", state: "active", by: by, direction: direction, limit: limit)
               |> json_response(200)

      plain_names = Enum.map(names, fn %{"name" => name} -> name end)

      assert length(names) <= limit
      assert ^plain_names = Enum.sort(plain_names)
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error_msg = "invalid query: by=#{by}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v3/names", state: "active", by: by) |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error_msg = "invalid direction: #{direction}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/names", state: "active", by: by, direction: direction)
               |> json_response(400)
    end

    test "it returns valid active names on a given range", %{conn: conn} do
      first = 100_000
      last = 1_500_000

      assert %{"data" => data} =
               conn
               |> get("/v3/names", state: "active", scope: "gen:#{first}-#{last}")
               |> json_response(200)

      assert Enum.count(data) > 0

      assert Enum.all?(data, fn %{"expire_height" => kbi} ->
               first <= kbi and kbi <= last
             end)
    end

    test "it returns valid active names on a given range, in reverse order", %{conn: conn} do
      first = 4_000_000
      last = 100_000

      assert %{"data" => data} =
               conn
               |> get("/v3/names", state: "active", scope: "gen:#{first}-#{last}")
               |> json_response(200)

      assert Enum.count(data) > 0

      assert Enum.all?(data, fn %{"expire_height" => kbi} ->
               last <= kbi and kbi <= first
             end)

      kbis =
        data |> Enum.map(fn %{"expire_height" => kbi} -> kbi end) |> Enum.reverse()

      assert Enum.sort(kbis) == kbis
    end
  end

  describe "inactive names" do
    test "get inactive names with default limit", %{conn: conn} do
      assert %{"data" => names, "next" => next} =
               conn |> get("/v3/names", state: "inactive") |> json_response(200)

      expirations =
        names
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert @default_limit = length(names)
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_names, "prev" => prev_names} =
               conn |> get(next) |> json_response(200)

      next_expirations =
        next_names
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert @default_limit = length(next_names)
      assert ^next_expirations = Enum.sort(next_expirations)
      assert Enum.at(expirations, @default_limit - 1) >= Enum.at(next_expirations, 0)

      assert %{"data" => ^names} = conn |> get(prev_names) |> json_response(200)
    end

    test "get inactive names forward with limit=6", %{conn: conn} do
      limit = 4
      state = State.new()

      assert %{"data" => names, "next" => next} =
               conn
               |> get("/v3/names", state: "inactive", direction: "forward", limit: limit)
               |> json_response(200)

      expirations =
        Enum.map(names, fn %{"expire_height" => expire_height, "revoke" => revoke} ->
          revoke_height = if revoke, do: Util.txi_to_gen(state, revoke)
          min(revoke_height, expire_height)
        end)

      assert ^limit = length(names)
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_names, "prev" => prev_names} =
               conn |> get(next) |> json_response(200)

      next_expirations =
        Enum.map(next_names, fn %{
                                  "expire_height" => expire_height,
                                  "revoke" => revoke
                                } ->
          revoke_height = if revoke, do: Util.txi_to_gen(state, revoke)
          min(revoke_height, expire_height)
        end)

      assert ^limit = length(next_names)
      assert Enum.at(expirations, limit - 1) <= Enum.at(next_expirations, 0)

      assert %{"data" => ^names} = conn |> get(prev_names) |> json_response(200)
    end

    test "get inactive names with parameters by=name, direction=forward and limit=4", %{
      conn: conn
    } do
      by = "name"
      direction = "forward"
      limit = 4

      assert %{"data" => names} =
               conn
               |> get("/v3/names", state: "inactive", by: by, direction: direction, limit: limit)
               |> json_response(200)

      plain_names = Enum.map(names, fn %{"name" => name} -> name end)

      assert ^limit = length(names)
      assert ^plain_names = Enum.sort(plain_names)
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error_msg = "invalid query: by=#{by}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v3/names", state: "inactive", by: by) |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error_msg = "invalid direction: #{direction}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/names", state: "inactive", by: by, direction: direction)
               |> json_response(400)
    end

    test "it returns valid names on a given range", %{conn: conn} do
      first = 100_000
      last = 500_000

      assert %{"data" => data, "next" => next} =
               conn
               |> get("/v3/names", state: "inactive", scope: "gen:#{first}-#{last}")
               |> json_response(200)

      assert Enum.count(data) > 0

      assert Enum.all?(data, fn %{"expire_height" => kbi} ->
               first <= kbi and kbi <= last
             end)

      assert @default_limit = length(data)

      assert %{"data" => data2} =
               conn
               |> get(next)
               |> json_response(200)

      assert @default_limit = length(data2)

      assert Enum.all?(data2, fn %{"expire_height" => kbi} ->
               first <= kbi and kbi <= last
             end)
    end

    test "it returns valid names on a given range, in reverse order", %{conn: conn} do
      first = 500_000
      last = 100_000

      assert %{"data" => data} =
               conn
               |> get("/v3/names", state: "inactive", scope: "gen:#{first}-#{last}")
               |> json_response(200)

      assert Enum.count(data) > 0

      assert Enum.all?(data, fn %{"expire_height" => kbi} ->
               last <= kbi and kbi <= first
             end)

      assert @default_limit = length(data)

      kbis =
        data |> Enum.map(fn %{"expire_height" => kbi} -> kbi end) |> Enum.reverse()

      assert Enum.sort(kbis) == kbis
    end
  end

  describe "auctions" do
    test "get auctions with default limit", %{conn: conn} do
      assert %{"data" => auctions} = conn |> get("/v3/names/auctions") |> json_response(200)

      expirations =
        auctions
        |> Enum.map(fn %{"auction_end" => expire} -> expire end)
        |> Enum.reverse()

      assert length(auctions) <= @default_limit
      assert ^expirations = Enum.sort(expirations)
    end

    test "get auctions with limit=2", %{conn: conn} do
      limit = 2

      assert %{"data" => auctions} =
               conn |> get("/v3/names/auctions", limit: limit) |> json_response(200)

      names =
        Enum.map(auctions, fn %{"name" => plain_name, "auction_end" => auction_end} ->
          {plain_name, auction_end}
        end)

      assert length(auctions) <= limit
      assert Enum.all?(names, fn {plain_name, _auction_end} -> plain_name != "" end)
      assert ^names = Enum.sort_by(names, fn {_name, expires} -> expires end, :desc)
    end

    test "get auctions with parameters by=expiration, direction=forward and limit=3", %{
      conn: conn
    } do
      limit = 3
      by = "expiration"
      direction = "forward"

      assert %{"data" => auctions} =
               conn
               |> get("/v3/names/auctions", by: by, direction: direction, limit: limit)
               |> json_response(200)

      expires = Enum.map(auctions, fn %{"auction_end" => expires} -> expires end)

      assert length(auctions) <= limit
      assert ^expires = Enum.sort(expires)
    end

    test "get auctions with parameters by=name, direction=backward and limit=3", %{
      conn: conn
    } do
      limit = 3
      by = "name"
      direction = "backward"

      assert %{"data" => auctions} =
               conn
               |> get("/v3/names/auctions", by: by, direction: direction, limit: limit)
               |> json_response(200)

      plain_names =
        auctions |> Enum.map(fn %{"name" => plain_name} -> plain_name end) |> Enum.reverse()

      assert length(auctions) <= limit
      assert ^plain_names = Enum.sort(plain_names)
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error_msg = "invalid query: by=#{by}"

      %{"error" => ^error_msg} = conn |> get("/v3/names/auctions", by: by) |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error_msg = "invalid direction: #{direction}"

      %{"error" => ^error_msg} =
        conn |> get("/v3/names/auctions", by: by, direction: direction) |> json_response(400)
    end
  end

  describe "names v3" do
    test "get active and inactive names, except those in auction, with default limit", %{
      conn: conn
    } do
      assert %{"data" => names, "next" => next} = conn |> get("/v3/names") |> json_response(200)

      expirations =
        names
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert @default_limit = length(names)
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_names} = conn |> get(next) |> json_response(200)

      next_expirations =
        next_names
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert @default_limit = length(next_expirations)
      assert ^next_expirations = Enum.sort(next_expirations)
      assert Enum.at(expirations, @default_limit - 1) >= Enum.at(next_expirations, 0)
    end

    test "get active and inactive names, except those in auction, with limit=2", %{conn: conn} do
      limit = 2
      assert %{"data" => names} = conn |> get("/v3/names", limit: limit) |> json_response(200)

      expirations =
        names
        |> Enum.map(fn %{"expire_height" => expire_height} -> expire_height end)
        |> Enum.reverse()

      assert ^limit = length(names)
      assert ^expirations = Enum.sort(expirations)
    end

    test "get active and inactive names, except those in auction, with parameters by=name, direction=forward and limit=4",
         %{conn: conn} do
      limit = 4
      by = "name"
      direction = "forward"

      assert %{"data" => names} =
               conn
               |> get("/v3/names", by: by, direction: direction, limit: limit)
               |> json_response(200)

      plain_names = Enum.map(names, fn %{"name" => plain_name} -> plain_name end)

      assert ^limit = length(names)
      assert ^plain_names = Enum.sort(plain_names)
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error_msg = "invalid query: by=#{by}"

      assert %{"error" => ^error_msg} = conn |> get("/v3/names", by: by) |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error_msg = "invalid direction: #{direction}"

      %{"error" => ^error_msg} =
        conn |> get("/v3/names", by: by, direction: direction) |> json_response(400)
    end

    test "it returns valid names on a given range", %{conn: conn} do
      first = 100_000
      last = 500_000

      assert %{"data" => data, "next" => next} =
               conn
               |> get("/v3/names", scope: "gen:#{first}-#{last}")
               |> json_response(200)

      assert Enum.count(data) > 0

      assert Enum.all?(data, fn %{"expire_height" => kbi} ->
               first <= kbi and kbi <= last
             end)

      assert @default_limit = length(data)

      assert %{"data" => data2} =
               conn
               |> get(next)
               |> json_response(200)

      assert @default_limit = length(data2)

      assert Enum.all?(data2, fn %{"expire_height" => kbi} ->
               first <= kbi and kbi <= last
             end)
    end

    test "it returns valid names on a given range, in reverse order", %{conn: conn} do
      first = 500_000
      last = 100_000

      assert %{"data" => data} =
               conn
               |> get("/v3/names", scope: "gen:#{first}-#{last}")
               |> json_response(200)

      assert Enum.all?(data, fn %{"expire_height" => kbi} ->
               last <= kbi and kbi <= first
             end)

      assert @default_limit = length(data)

      kbis = data |> Enum.map(fn %{"expire_height" => kbi} -> kbi end) |> Enum.reverse()

      assert ^kbis = Enum.sort(kbis)
    end
  end

  describe "names" do
    test "it get active names backwards without any filters", %{conn: conn} do
      assert %{"data" => names, "next" => next} =
               conn |> get("/v2/names", state: "active") |> json_response(200)

      expirations =
        names
        |> Enum.map(fn %{"info" => %{"expire_height" => expire_height}} -> expire_height end)
        |> Enum.reverse()

      assert length(names) <= @default_limit
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_names, "prev" => prev_names} =
               conn |> get(next) |> json_response(200)

      if next do
        next_expirations =
          next_names
          |> Enum.map(fn %{"info" => %{"expire_height" => expire_height}} -> expire_height end)
          |> Enum.reverse()

        assert length(next_names) <= @default_limit
        assert ^next_expirations = Enum.sort(next_expirations)
        assert Enum.at(expirations, @default_limit - 1) >= Enum.at(next_expirations, 0)

        assert %{"data" => ^names} = conn |> get(prev_names) |> json_response(200)
      end
    end

    test "it get active names backwards by default with by=deactivation", %{conn: conn} do
      assert %{"data" => names, "next" => next} =
               conn |> get("/v2/names?by=deactivation", state: "active") |> json_response(200)

      expirations =
        names
        |> Enum.map(fn %{"info" => %{"expire_height" => expire_height}} -> expire_height end)
        |> Enum.reverse()

      assert length(names) <= @default_limit
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_names, "prev" => prev_names} =
               conn |> get(next) |> json_response(200)

      if next do
        next_expirations =
          next_names
          |> Enum.map(fn %{"info" => %{"expire_height" => expire_height}} -> expire_height end)
          |> Enum.reverse()

        assert length(next_names) <= @default_limit
        assert ^next_expirations = Enum.sort(next_expirations)
        assert Enum.at(expirations, @default_limit - 1) >= Enum.at(next_expirations, 0)

        assert %{"data" => ^names} = conn |> get(prev_names) |> json_response(200)
      end
    end

    test "get active names forward with limit=4", %{conn: conn} do
      limit = 4

      assert %{"data" => names, "next" => next} =
               conn
               |> get("/v2/names", state: "active", direction: "forward", limit: limit)
               |> json_response(200)

      expirations =
        Enum.map(names, fn %{"info" => %{"expire_height" => expire_height}} -> expire_height end)

      assert length(names) <= limit
      assert ^expirations = Enum.sort(expirations)

      if next do
        assert %{"data" => next_names, "prev" => prev_names} =
                 conn |> get(next) |> json_response(200)

        next_expirations =
          Enum.map(next_names, fn %{"info" => %{"expire_height" => expire_height}} ->
            expire_height
          end)

        assert length(next_names) <= 4
        assert ^next_expirations = Enum.sort(next_expirations)
        assert Enum.at(expirations, limit - 1) <= Enum.at(next_expirations, 0)

        assert %{"data" => ^names} = conn |> get(prev_names) |> json_response(200)
      end
    end

    test "get active names with parameters by=name, direction=forward and limit=3", %{conn: conn} do
      by = "name"
      direction = "forward"
      limit = 3

      assert %{"data" => names} =
               conn
               |> get("/v2/names", state: "active", by: by, direction: direction, limit: limit)
               |> json_response(200)

      plain_names = Enum.map(names, fn %{"name" => name} -> name end)

      assert length(names) <= limit
      assert ^plain_names = Enum.sort(plain_names)
    end

    test "when filtering by owned_by, it returns names owned by that owner", %{conn: conn} do
      # first, retrieve any name to get the owner
      assert %{"data" => [%{"info" => %{"ownership" => %{"current" => owner_pk}}} | _rest]} =
               conn |> get("/v2/names", state: "active", limit: 1) |> json_response(200)

      assert %{"data" => names} =
               conn
               |> get("/v2/names", state: "active", by: "name", owned_by: owner_pk, limit: 3)
               |> json_response(200)

      assert Enum.all?(
               names,
               &match?(%{"info" => %{"ownership" => %{"current" => ^owner_pk}}}, &1)
             )
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error_msg = "invalid query: by=#{by}"

      assert %{"error" => ^error_msg} = conn |> get("/v2/names", by: by) |> json_response(400)
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error_msg = "invalid direction: #{direction}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/names", by: by, direction: direction) |> json_response(400)
    end

    test "returns names when filtering by owner with expiration order", %{conn: conn} do
      id = "ak_KR3a8dukEYVoZPoWFaszFgjKUpBh7J1Q5iWsz9YCamHn2rTCp"

      assert %{"data" => [name1]} =
               conn
               |> get("/v2/names", owned_by: id, direction: "forward", limit: 1)
               |> json_response(200)

      assert %{
               "hash" => "nm_U1na6mYmpy2GDxcoMQyZ5tL2KRp1b3a4aPdq5sqY5k38KfhW6",
               "name" => "2transferlongname.chain",
               "previous" => [],
               "status" => "name"
             } = name1
    end

    test "renders error when scoping names sorted by name", %{conn: conn} do
      error_msg = "invalid query: can't scope names sorted by name"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/names", by: "name", scope: "gen:10-100") |> json_response(400)
    end

    test "it returns valid names on a given range", %{conn: conn} do
      first = 100_000
      last = 500_000

      assert %{"data" => data} =
               conn
               |> get("/v2/names", state: "active", scope: "gen:#{first}-#{last}")
               |> json_response(200)

      assert Enum.all?(data, fn %{"info" => %{"expire_height" => kbi}} ->
               first <= kbi and kbi <= last
             end)
    end

    test "it returns valid names on a given range, in reverse order", %{conn: conn} do
      first = 4_000_000
      last = 100_000

      assert %{"data" => data} =
               conn
               |> get("/v2/names", state: "active", scope: "gen:#{first}-#{last}")
               |> json_response(200)

      assert Enum.all?(data, fn %{"info" => %{"expire_height" => kbi}} ->
               last <= kbi and kbi <= first
             end)

      kbis =
        data |> Enum.map(fn %{"info" => %{"expire_height" => kbi}} -> kbi end) |> Enum.reverse()

      assert Enum.sort(kbis) == kbis
    end

    test "get inactive names with default limit", %{conn: conn} do
      assert %{"data" => names, "next" => next} =
               conn |> get("/v2/names", state: "inactive") |> json_response(200)

      expirations =
        names
        |> Enum.map(fn %{"info" => %{"expire_height" => expire_height}} -> expire_height end)
        |> Enum.reverse()

      assert @default_limit = length(names)
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_names, "prev" => prev_names} =
               conn |> get(next) |> json_response(200)

      next_expirations =
        next_names
        |> Enum.map(fn %{"info" => %{"expire_height" => expire_height}} -> expire_height end)
        |> Enum.reverse()

      assert @default_limit = length(next_names)
      assert ^next_expirations = Enum.sort(next_expirations)
      assert Enum.at(expirations, @default_limit - 1) >= Enum.at(next_expirations, 0)

      assert %{"data" => ^names} = conn |> get(prev_names) |> json_response(200)
    end

    test "get inactive names forward with limit=6", %{conn: conn} do
      limit = 4
      state = State.new()

      assert %{"data" => names, "next" => next} =
               conn
               |> get("/v2/names", state: "inactive", direction: "forward", limit: limit)
               |> json_response(200)

      expirations =
        Enum.map(names, fn %{"info" => %{"expire_height" => expire_height, "revoke" => revoke}} ->
          revoke_height = if revoke, do: Util.txi_to_gen(state, revoke)
          min(revoke_height, expire_height)
        end)

      assert ^limit = length(names)
      assert ^expirations = Enum.sort(expirations)

      assert %{"data" => next_names, "prev" => prev_names} =
               conn |> get(next) |> json_response(200)

      next_expirations =
        Enum.map(next_names, fn %{
                                  "info" => %{
                                    "expire_height" => expire_height,
                                    "revoke" => revoke
                                  }
                                } ->
          revoke_height = if revoke, do: Util.txi_to_gen(state, revoke)
          min(revoke_height, expire_height)
        end)

      assert ^limit = length(next_names)
      assert ^next_expirations = Enum.sort(next_expirations)
      assert Enum.at(expirations, limit - 1) <= Enum.at(next_expirations, 0)

      assert %{"data" => ^names} = conn |> get(prev_names) |> json_response(200)
    end

    test "get inactive names with parameters by=name, direction=forward and limit=4", %{
      conn: conn
    } do
      by = "name"
      direction = "forward"
      limit = 4

      assert %{"data" => names} =
               conn
               |> get("/v2/names", state: "inactive", by: by, direction: direction, limit: limit)
               |> json_response(200)

      plain_names = Enum.map(names, fn %{"name" => name} -> name end)

      assert ^limit = length(names)
      assert ^plain_names = Enum.sort(plain_names)
    end

    test "it returns valid inactive names on a given range", %{conn: conn} do
      first = 100_000
      last = 500_000

      assert %{"data" => data, "next" => next} =
               conn
               |> get("/v2/names", state: "inactive", scope: "gen:#{first}-#{last}")
               |> json_response(200)

      assert Enum.all?(data, fn %{"info" => %{"expire_height" => kbi}} ->
               first <= kbi and kbi <= last
             end)

      assert @default_limit = length(data)

      assert %{"data" => data2} =
               conn
               |> get(next)
               |> json_response(200)

      assert @default_limit = length(data2)

      assert Enum.all?(data2, fn %{"info" => %{"expire_height" => kbi}} ->
               first <= kbi and kbi <= last
             end)
    end

    test "it returns valid inactive names on a given range, in reverse order", %{conn: conn} do
      first = 500_000
      last = 100_000

      assert %{"data" => data} =
               conn
               |> get("/v2/names", state: "inactive", scope: "gen:#{first}-#{last}")
               |> json_response(200)

      assert Enum.all?(data, fn %{"info" => %{"expire_height" => kbi}} ->
               last <= kbi and kbi <= first
             end)

      assert @default_limit = length(data)

      kbis =
        data |> Enum.map(fn %{"info" => %{"expire_height" => kbi}} -> kbi end) |> Enum.reverse()

      assert Enum.sort(kbis) == kbis
    end

    test "when retrieving names with tx_hash=true, it displays the extends/claims tx hashes", %{
      conn: conn
    } do
      assert %{"data" => names} = conn |> get("/v2/names", tx_hash: "true") |> json_response(200)

      assert Enum.all?(names, fn %{
                                   "info" => %{
                                     "claims" => claims,
                                     "updates" => updates,
                                     "transfers" => transfers
                                   }
                                 } ->
               Enum.all?(claims ++ updates ++ transfers, fn tx_hash ->
                 match?(
                   {:ok, _encoded_tx_hash},
                   :aeser_api_encoder.safe_decode(:tx_hash, tx_hash)
                 )
               end)
             end)
    end
  end

  describe "name v3" do
    test "get info by plain name", %{conn: conn} do
      name = "wwwbeaconoidcom.chain"
      state = State.new()
      conn = get(conn, "/v3/names/#{name}")

      auto_assert(
        %{
          "active" => false,
          "active_from" => 279_555,
          "approximate_activation_time" => 1_593_861_576_848,
          "approximate_expire_time" => 1_602_925_509_746,
          "auction" => nil,
          "auction_timeout" => 0,
          "claims_count" => 1,
          "expire_height" => 329_558,
          "hash" => "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj",
          "name" => ^name,
          "name_fee" => 676_500_000_000_000_000,
          "ownership" => %{
            "current" => "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C",
            "original" => "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
          },
          "pointers" => [
            %{
              "encoded_key" => "ba_YWNjb3VudF9wdWJrZXn8jckR",
              "id" => "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C",
              "key" => "account_pubkey"
            }
          ],
          "revoke" => nil
        } <- json_response(conn, 200)
      )
    end

    test "get by plain name a name with transfer by internal call", %{conn: conn} do
      name = "888888888888.chain"
      state = State.new()
      conn = get(conn, "/v3/names/#{name}")

      auto_assert(
        %{
          "active" => false,
          "active_from" => 407_444,
          "approximate_activation_time" => 1_617_160_081_296,
          "approximate_expire_time" => 1_626_220_134_341,
          "auction" => nil,
          "auction_timeout" => 480,
          "claims_count" => 1,
          "expire_height" => 457_444,
          "hash" => "nm_2fuGfCxc4cGRNCLHCLWduNjwJwkA6pLdSRmjoB42yBXQSbtFiE",
          "name" => ^name,
          "name_fee" => 2_865_700_000_000_000_000,
          "ownership" => %{
            "current" => "ak_u65a7fufWdCNxC54cYwo9oFtcH5XEFxiHTGPQKVAn99XLSRqq",
            "original" => "ak_u65a7fufWdCNxC54cYwo9oFtcH5XEFxiHTGPQKVAn99XLSRqq"
          },
          "pointers" => [],
          "revoke" => nil
        } <- json_response(conn, 200)
      )
    end

    test "get name info by encoded hash ", %{conn: conn} do
      hash = "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj"
      state = State.new()
      conn = get(conn, "/v3/names/#{hash}")

      auto_assert(
        %{
          "active" => false,
          "active_from" => 279_555,
          "approximate_activation_time" => 1_593_861_576_848,
          "approximate_expire_time" => 1_602_925_509_746,
          "auction" => nil,
          "auction_timeout" => 0,
          "claims_count" => 1,
          "expire_height" => 329_558,
          "hash" => ^hash,
          "name" => "wwwbeaconoidcom.chain",
          "name_fee" => 676_500_000_000_000_000,
          "ownership" => %{
            "current" => "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C",
            "original" => "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
          },
          "pointers" => [
            %{
              "encoded_key" => "ba_YWNjb3VudF9wdWJrZXn8jckR",
              "id" => "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C",
              "key" => "account_pubkey"
            }
          ],
          "revoke" => nil
        } <- json_response(conn, 200)
      )
    end

    test "renders error when no such name is present", %{conn: conn} do
      name = "no--such--name--in--the--chain.chain"
      state = State.new()
      conn = get(conn, "/v3/names/#{name}")

      auto_assert(
        %{"error" => "not found: no--such--name--in--the--chain.chain"} <-
          json_response(conn, 404)
      )
    end
  end

  describe "name" do
    test "get info by plain name", %{conn: conn} do
      name = "wwwbeaconoidcom.chain"
      state = State.new()
      conn = get(conn, "/v2/names/#{name}")

      assert json_response(conn, 200) ==
               TestUtil.handle_input(fn -> get_name(Validate.plain_name!(state, name)) end)
    end

    test "get by plain name a name with transfer by internal call", %{conn: conn} do
      name = "888888888888.chain"
      state = State.new()
      conn = get(conn, "/v2/names/#{name}")

      assert json_response(conn, 200) ==
               TestUtil.handle_input(fn -> get_name(Validate.plain_name!(state, name)) end)
    end

    test "get name in auction with expand=true", %{conn: conn} do
      auto_assert(
        %{
          "active" => true,
          "info" => %{
            "active_from" => 628_354,
            "auction_timeout" => 29_760,
            "claims" => [
              %{
                "block_hash" => "mh_aTXPPMkfqYGcbVHdw8CvzzzCMUi1S6QBXJAfpNPCSzM9ZQCMT",
                "block_height" => 598_594,
                "encoded_tx" =>
                  "tx_+JQLAfhCuEC0rGlbfAfnegjKN+h0Om/Wt5k7SAi9ysn17DMoyB6wexHDr7FiBio0ToVc7TuAYZikRjFqmh0PxkKayj23TP8GuEz4SiACoQGRhoFvomIXy88hLGMHjb+8xuaUhGPlKKyZcgt+LNiFsiqKVGVzdC5jaGFpbocOe/UPdE92iQdMUtREIAlAAIYPBly7UAAAqJx6wA==",
                "hash" => "th_2oYzaajiB7HQCGBJquynccJ7VFQ26Dh7btvSuxSLqRKw5WFBLn",
                "micro_index" => 2,
                "micro_time" => 1_652_436_056_054,
                "signatures" => [
                  "sg_QdxfKCupxaon8kj48LZFtULwmB2FNP96LZTXHbXcFLwUNwxGgiw939J352er8K7EGCweF7182y1ewQCe6w1QgGQa35gvH"
                ],
                "tx" => %{
                  "account_id" => "ak_276FaXv9UX1kEgQMar4dQyEYneTD5MiyZfRpJbuU5UyYDFvRdq",
                  "fee" => 16_520_000_000_000,
                  "name" => "Test.chain",
                  "name_fee" => 134_626_900_000_000_000_000,
                  "name_id" => "nm_cVjoMBVH5UAthDx8hEijr5dF21yex6itrxbZZUMaftL941g9G",
                  "name_salt" => 4_076_942_130_433_910,
                  "nonce" => 42,
                  "type" => "NameClaimTx",
                  "version" => 2
                },
                "tx_index" => 32_273_378
              }
            ],
            "expire_height" => 1_128_852,
            "ownership" => %{
              "current" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321",
              "original" => "ak_276FaXv9UX1kEgQMar4dQyEYneTD5MiyZfRpJbuU5UyYDFvRdq"
            },
            "pointers" => %{
              "account_pubkey" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321"
            },
            "revoke" => nil,
            "transfers" => [
              %{
                "block_hash" => "mh_rk8tv5hu49fYwCGZuLgkY2Y8V3LmkSWNdMnZq3YU1cDEYEvrT",
                "block_height" => 644_955,
                "encoded_tx" =>
                  "tx_+LsLAfhCuECXx79/2xzqi2Cv8HYj9R5AUrJPDzhcqVcxLiNtwcTxLonOaTqbLt6vjdr6TUNIbSy3ZvkRhqMjzx/UgjCt77QOuHP4cSQBoQGRhoFvomIXy88hLGMHjb+8xuaUhGPlKKyZcgt+LNiFslKhAlCYygTo5mrGvATbkThUR6EXecvfzfsug8dFPZFieKO3oQHG2j0wLmzayVc8jnGzlENF6/4ItQJmy2QAh9ogGzY3UIYPu/hayAAAo0jqiA==",
                "hash" => "th_25Ucn6gatD7teVNZtQuQtSvPizWvb1mix9ysjQ3CY1miQqVHMk",
                "micro_index" => 105,
                "micro_time" => 1_661_103_019_536,
                "signatures" => [
                  "sg_LriZ9PteHWGVdidbBhcHiE6uXKmxdN6x7RgmaS177CCrZyqEz648cxxBLdfa6mBY9ofQGkw4NtjDE3SmyGHDm6DFBpb5X"
                ],
                "tx" => %{
                  "account_id" => "ak_276FaXv9UX1kEgQMar4dQyEYneTD5MiyZfRpJbuU5UyYDFvRdq",
                  "fee" => 17_300_000_000_000,
                  "name" => "test.chain",
                  "name_id" => "nm_cVjoMBVH5UAthDx8hEijr5dF21yex6itrxbZZUMaftL941g9G",
                  "nonce" => 82,
                  "recipient_id" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321",
                  "type" => "NameTransferTx",
                  "version" => 1
                },
                "tx_index" => 33_302_871
              }
            ],
            "updates" => [
              %{
                "block_hash" => "mh_9VduV1f7ZTgihfLch3EZUumbueawhTRhmjKTzBb2QRjE8UtBt",
                "block_height" => 948_852,
                "encoded_tx" =>
                  "tx_+NgLAfhCuECIBIEmUGGGcEHeg5gEf6VtopRPjC6cDTGgUcN3bdB99JsfpBE9J+RkTIjgmbQFQnbE9rYUTzzhVmSg8fmXH2QFuJD4jiIBoQHG2j0wLmzayVc8jnGzlENF6/4ItQJmy2QAh9ogGzY3UIIFN6ECUJjKBOjmasa8BNuROFRHoRd5y9/N+y6Dx0U9kWJ4o7eDAr8g8vGOYWNjb3VudF9wdWJrZXmhAcbaPTAubNrJVzyOcbOUQ0Xr/gi1AmbLZACH2iAbNjdQgg4QhhBDAwxwAIMOenc5YRZ3",
                "hash" => "th_owrL72DuBeowQAv4YeRLGrYDvLpXd3fzCDoCvbq4mK4gzxHtP",
                "micro_index" => 17,
                "micro_time" => 1_716_379_835_614,
                "signatures" => [
                  "sg_Jo7HzxRdYJJ1k7gANpJc12XdRCYYVoMZ65Ma3mgQ8jUwCZLgzpaS4hG3KzgtN4ibGNpWDmnNiM15Q4hq7aG4cS1V6Mf4r"
                ],
                "tx" => %{
                  "account_id" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321",
                  "client_ttl" => 3600,
                  "fee" => 17_880_000_000_000,
                  "name" => "test.chain",
                  "name_id" => "nm_cVjoMBVH5UAthDx8hEijr5dF21yex6itrxbZZUMaftL941g9G",
                  "name_ttl" => 180_000,
                  "nonce" => 1335,
                  "pointers" => [
                    %{
                      "id" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321",
                      "key" => "account_pubkey"
                    }
                  ],
                  "ttl" => 948_855,
                  "type" => "NameUpdateTx",
                  "version" => 1
                },
                "tx_index" => 65_658_114
              },
              %{
                "block_hash" => "mh_12zxszW7uLDSngpdjgYr4sZHJSuwYensJLDRDnXoHh4EKoytY",
                "block_height" => 896_766,
                "encoded_tx" =>
                  "tx_+NYLAfhCuEDw9+ZpG0yheS0UiRzPej0PJWiE9j+xlu2xzp+qD/sEER3cIAAqPwnnM9fWnYfotWnyIZ4lxA8w2OmLyEvxFT0KuI74jCIBoQHG2j0wLmzayVc8jnGzlENF6/4ItQJmy2QAh9ogGzY3UIID3aECUJjKBOjmasa8BNuROFRHoRd5y9/N+y6Dx0U9kWJ4o7eDAr8g8vGOYWNjb3VudF9wdWJrZXmhAcbaPTAubNrJVzyOcbOUQ0Xr/gi1AmbLZACH2iAbNjdQgwFKeIYQObLc4AAATff2kw==",
                "hash" => "th_JCqpkU3z1yZNyS2Ft9w3MCjvXAZjNM6v9aENp9eosLdpi1inU",
                "micro_index" => 7,
                "micro_time" => 1_706_908_117_970,
                "signatures" => [
                  "sg_YXUrgvvfpEWMyvE4oXqiEX9dwwmZ5mVsPn1yrCerJmWJbxZm1zjC4GNVv1nKHMUgCubFuA4yegun7FGuhZLQidejcKsNr"
                ],
                "tx" => %{
                  "account_id" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321",
                  "client_ttl" => 84_600,
                  "fee" => 17_840_000_000_000,
                  "name" => "test.chain",
                  "name_id" => "nm_cVjoMBVH5UAthDx8hEijr5dF21yex6itrxbZZUMaftL941g9G",
                  "name_ttl" => 180_000,
                  "nonce" => 989,
                  "pointers" => [
                    %{
                      "id" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321",
                      "key" => "account_pubkey"
                    }
                  ],
                  "type" => "NameUpdateTx",
                  "version" => 1
                },
                "tx_index" => 60_554_040
              },
              %{
                "block_hash" => "mh_TicCToXxULWfeBFyExZAProhtAhqhfAQF3zqEwB3Cv5DLrtFu",
                "block_height" => 760_294,
                "encoded_tx" =>
                  "tx_+NYLAfhCuEDUSnl0oUrF0wtu711S3Fwyswb53N3YwU7QIgDovjZlmDKr97xY9225V+bLrZswAivrpDfN95OE6VhfqCxHB9kEuI74jCIBoQHG2j0wLmzayVc8jnGzlENF6/4ItQJmy2QAh9ogGzY3UIICd6ECUJjKBOjmasa8BNuROFRHoRd5y9/N+y6Dx0U9kWJ4o7eDAr8g8vGOYWNjb3VudF9wdWJrZXmhAcbaPTAubNrJVzyOcbOUQ0Xr/gi1AmbLZACH2iAbNjdQgwFKeIYQObLc4AAAf/bJJw==",
                "hash" => "th_26XkTUfEqTejC2XdeTW8nwaxRWyb8eKRDL1FvL7Kf4fpvVEkHL",
                "micro_index" => 79,
                "micro_time" => 1_682_111_406_008,
                "signatures" => [
                  "sg_UmsiPR8BqPywuKRHQR27scufmFLss49HwQuSjNP88hUtBY9KLPRRMBZTZgZgNS9bttVRKSXURZvdhFXbRXGGhVUFfcnU8"
                ],
                "tx" => %{
                  "account_id" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321",
                  "client_ttl" => 84_600,
                  "fee" => 17_840_000_000_000,
                  "name" => "test.chain",
                  "name_id" => "nm_cVjoMBVH5UAthDx8hEijr5dF21yex6itrxbZZUMaftL941g9G",
                  "name_ttl" => 180_000,
                  "nonce" => 631,
                  "pointers" => [
                    %{
                      "id" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321",
                      "key" => "account_pubkey"
                    }
                  ],
                  "type" => "NameUpdateTx",
                  "version" => 1
                },
                "tx_index" => 41_167_123
              },
              %{
                "block_hash" => "mh_t6jdVzs5TxvViAjmEmNxCcD77mXhVXn5u8WxuNm5dr6nU6H4x",
                "block_height" => 645_760,
                "encoded_tx" =>
                  "tx_+NYLAfhCuEAxMTvJ0tUveW+jIfT1w6dlPK7oeQy7wDVknKghU6DzQtpInNK1cMIOPVCaKnSZO/jivT2kpHEU0sHnFx1F738BuI74jCIBoQHG2j0wLmzayVc8jnGzlENF6/4ItQJmy2QAh9ogGzY3UIIBEqECUJjKBOjmasa8BNuROFRHoRd5y9/N+y6Dx0U9kWJ4o7eDAr8g8vGOYWNjb3VudF9wdWJrZXmhAcbaPTAubNrJVzyOcbOUQ0Xr/gi1AmbLZACH2iAbNjdQgwFKeIYQObLc4AAAY6Cahw==",
                "hash" => "th_2RNiYXEzr8ZG3xpsXVHx24viMBoERRWrJzKARLNRb2EwEjsPw7",
                "micro_index" => 12,
                "micro_time" => 1_661_253_919_706,
                "signatures" => [
                  "sg_7SGtCPUg45hAvBKdddBFQ3iiK5MaP3LhDSCGoCMrwW8Q9ZU2BqHeqbfcnvHBzXffs4DwEJfu4oESXostRpteMZn91hREs"
                ],
                "tx" => %{
                  "account_id" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321",
                  "client_ttl" => 84_600,
                  "fee" => 17_840_000_000_000,
                  "name" => "test.chain",
                  "name_id" => "nm_cVjoMBVH5UAthDx8hEijr5dF21yex6itrxbZZUMaftL941g9G",
                  "name_ttl" => 180_000,
                  "nonce" => 274,
                  "pointers" => [
                    %{
                      "id" => "ak_2WaRNJe5ohzCPXrJrU6U3U5LZfXYgoTTSjjGPonTeQSGRP8321",
                      "key" => "account_pubkey"
                    }
                  ],
                  "type" => "NameUpdateTx",
                  "version" => 1
                },
                "tx_index" => 33_334_255
              }
            ]
          },
          "name" => "test.chain",
          "previous" => [],
          "status" => "name"
        } <-
          conn
          |> get("/v2/names/test.chain?expand=true")
          |> json_response(200)
      )
    end

    test "get name info by encoded hash ", %{conn: conn} do
      hash = "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj"
      state = State.new()
      conn = get(conn, "/v2/names/#{hash}")

      assert json_response(conn, 200) ==
               TestUtil.handle_input(fn -> get_name(Validate.plain_name!(state, hash)) end)
    end

    test "renders error when no such name is present", %{conn: conn} do
      name = "no--such--name--in--the--chain.chain"
      state = State.new()
      conn = get(conn, "/v2/names/#{name}")

      assert json_response(conn, 404) == %{
               "error" =>
                 TestUtil.handle_input(fn -> get_name(Validate.plain_name!(state, name)) end)
             }
    end
  end

  describe "pointees v3" do
    test "get pointees for valid public key", %{conn: conn} do
      id = "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
      conn = get(conn, "/v3/accounts/#{id}/names/pointees/")

      auto_assert(
        %{
          "data" => [
            %{
              "active" => false,
              "block_hash" => "mh_2f9F14PvtVmfqAZnBi5rAsCZinxCK1tmTn1dWQHShJY22KgLBt",
              "block_height" => 279_558,
              "block_time" => 1_593_862_096_625,
              "key" => "account_pubkey",
              "name" => "wwwbeaconoidcom.chain",
              "source_tx_hash" => "th_2rnypSgKfSZWat1t8Cw9Svuhwtm8gQVHggahZ4avi3UKBZwUKd",
              "source_tx_type" => "NameUpdateTx",
              "tx" => %{
                "account_id" => ^id,
                "client_ttl" => 84_600,
                "fee" => 17_780_000_000_000,
                "name_id" => "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj",
                "name_ttl" => 50_000,
                "nonce" => 3,
                "pointers" => [
                  %{
                    "encoded_key" => "ba_YWNjb3VudF9wdWJrZXn8jckR",
                    "id" => ^id,
                    "key" => "account_pubkey"
                  }
                ],
                "ttl" => 0
              }
            }
          ],
          "next" => nil,
          "prev" => nil
        } <- json_response(conn, 200)
      )
    end

    test "renders error when the key is invalid", %{conn: conn} do
      id = "ak_invalidkey"
      conn = get(conn, "/v3/accounts/#{id}/names/pointees")

      assert json_response(conn, 400) ==
               %{
                 "error" =>
                   TestUtil.handle_input(fn ->
                     get_pointees(Validate.name_id!(id))
                   end)
               }
    end
  end

  describe "pointees" do
    test "get pointees for valid public key", %{conn: conn} do
      id = "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
      conn = get(conn, "/v2/names/#{id}/pointees")

      assert json_response(conn, 200) ==
               TestUtil.handle_input(fn -> get_pointees(Validate.name_id!(id)) end)
    end

    test "renders error when the key is invalid", %{conn: conn} do
      id = "ak_invalidkey"
      conn = get(conn, "/v2/names/#{id}/pointees")

      assert json_response(conn, 400) ==
               %{
                 "error" =>
                   TestUtil.handle_input(fn ->
                     get_pointees(Validate.name_id!(id))
                   end)
               }
    end
  end

  describe "owned_by" do
    test "get active names owned by an account", %{conn: conn} do
      id = "ak_KR3a8dukEYVoZPoWFaszFgjKUpBh7J1Q5iWsz9YCamHn2rTCp"
      conn = get(conn, "/v3/names", owned_by: id, state: "active")

      %{"data" => data} = json_response(conn, 200)

      assert Enum.each(data, fn %{
                                  "active" => true,
                                  "name" => plain_name,
                                  "hash" => hash,
                                  "ownership" => %{"current" => owner}
                                } ->
               assert owner == id

               expected_hash =
                 case :aens.get_name_hash(plain_name) do
                   {:ok, name_id_bin} -> Enc.encode(:name, name_id_bin)
                   _error -> nil
                 end

               assert hash == expected_hash
             end)
    end

    test "it renders last bid for names that are in auction", %{conn: conn} do
      %{"data" => auctions} = conn |> get("/v3/names/auctions") |> json_response(200)

      assert Enum.all?(auctions, fn %{"last_bid" => %{}} -> true end)
    end

    test "get inactive names that were owned by an account", %{conn: conn} do
      id = "ak_fCCw1JEkvXdztZxk8FRGNAkvmArhVeow89e64yX4AxbCPrVh5"

      %{"data" => data} =
        conn
        |> get("/v3/names", owned_by: id, state: "inactive")
        |> json_response(200)

      Enum.each(data, fn %{
                           "active" => false,
                           "ownership" => %{"current" => last_owner}
                         } ->
        assert last_owner == id
      end)
    end

    test "renders error when the key is invalid", %{conn: conn} do
      id = "ak_invalid_key"
      conn = get(conn, "/v3/names", owned_by: id)

      assert json_response(conn, 400) == %{"error" => "invalid id: #{id}"}
    end
  end

  describe "search" do
    test "it returns an all matching names & auctions", %{conn: conn} do
      prefix = "xyz"

      assert %{"data" => names_and_auctions, "next" => next} =
               conn |> get("/v2/names/search", prefix: prefix) |> json_response(200)

      plain_names =
        names_and_auctions
        |> Enum.map(fn
          %{"type" => "name", "payload" => %{"name" => name}} -> name
          %{"type" => "auction", "payload" => %{"name" => name}} -> name
        end)
        |> Enum.reverse()

      assert @default_limit = length(names_and_auctions)
      assert ^plain_names = Enum.sort(plain_names)
      assert Enum.all?(plain_names, &String.starts_with?(&1, prefix))

      %{"data" => next_names_and_auctions} = conn |> get(next) |> json_response(200)

      next_plain_names =
        next_names_and_auctions
        |> Enum.map(fn
          %{"type" => "name", "payload" => %{"name" => name}} -> name
          %{"type" => "auction", "payload" => %{"name" => name}} -> name
        end)
        |> Enum.reverse()

      assert @default_limit = length(next_names_and_auctions)
      assert ^next_plain_names = Enum.sort(next_plain_names)
      assert Enum.all?(next_plain_names, &String.starts_with?(&1, prefix))

      assert Enum.at(plain_names, @default_limit - 1) >= Enum.at(next_plain_names, 0)
    end

    test "it returns an all matching names & auctions forward", %{conn: conn} do
      prefix = "xyz"

      assert %{"data" => names_and_auctions, "next" => next} =
               conn
               |> get("/v2/names/search", prefix: prefix, direction: "forward")
               |> json_response(200)

      plain_names =
        Enum.map(names_and_auctions, fn
          %{"type" => "name", "payload" => %{"name" => name}} -> name
          %{"type" => "auction", "payload" => %{"name" => name}} -> name
        end)

      assert @default_limit = length(names_and_auctions)
      assert ^plain_names = Enum.sort(plain_names)
      assert Enum.all?(plain_names, &String.starts_with?(&1, prefix))

      %{"data" => next_names_and_auctions} = conn |> get(next) |> json_response(200)

      next_plain_names =
        Enum.map(next_names_and_auctions, fn
          %{"type" => "name", "payload" => %{"name" => name}} -> name
          %{"type" => "auction", "payload" => %{"name" => name}} -> name
        end)

      assert @default_limit = length(next_names_and_auctions)
      assert ^next_plain_names = Enum.sort(next_plain_names)
      assert Enum.all?(next_plain_names, &String.starts_with?(&1, prefix))
    end
  end

  describe "names count" do
    test "it counts active names for a user", %{conn: conn} do
      user_pks =
        conn
        |> get("/v3/names")
        |> json_response(200)
        |> then(fn %{"data" => data} ->
          data
          |> Enum.map(fn %{"ownership" => %{"current" => pk}} -> pk end)
          |> Enum.uniq()
        end)

      for user_pk <- user_pks do
        all =
          conn
          |> get("/v3/names", owned_by: user_pk)
          |> json_response(200)
          |> IntegrationUtil.scan(conn, [], &Kernel.++/2)

        assert all > 0

        active =
          conn
          |> get("/v3/names/count", owned_by: user_pk)
          |> json_response(200)

        assert active ==
                 all
                 |> Enum.filter(fn %{"active" => active} -> active end)
                 |> length()
      end
    end
  end

  ##########

  defp get_name(name) do
    state = State.new()

    case Name.locate_name(state, name) do
      {info, source} ->
        Format.to_map(state, info, source)

      nil ->
        raise ErrInput.NotFound, value: name
    end
  end

  defp get_pointees(pubkey) do
    state = State.new()

    {active, inactive} = Name.pointees(state, pubkey)

    %{
      "active" => Format.map_raw_values(active, &Format.to_json/1),
      "inactive" => Format.map_raw_values(inactive, &Format.to_json/1)
    }
  end
end
