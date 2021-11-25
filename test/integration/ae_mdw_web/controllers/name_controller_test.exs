defmodule Integration.AeMdwWeb.NameControllerTest do
  use AeMdwWeb.ConnCase

  alias :aeser_api_encoder, as: Enc

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Util
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate

  alias AeMdwWeb.Continuation, as: Cont
  alias AeMdwWeb.NameController
  alias AeMdwWeb.TestUtil

  import AeMdw.Util
  import AeMdwWeb.Util

  require Model

  @moduletag :integration

  @default_limit 10

  describe "active_names" do
    test "get active names with default limit", %{conn: conn} do
      conn = get(conn, "/names/active")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :active_names, %{}, :unused_scope, 0},
          @default_limit
        )

      assert Enum.count(response["data"]) == @default_limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {NameController, :active_names, %{}, :unused_scope, @default_limit},
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
          {NameController, :active_names, %{}, :unused_scope, 0},
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
           :unused_scope, 0},
          limit
        )

      assert Enum.count(response["data"]) <= limit
      assert response["data"] == data
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

      assert json_response(conn, 400) == %{"error" => "invalid direction: #{direction}"}
    end

    test "it returns valid names on a given range", %{conn: conn} do
      first = 100_000
      last = 500_000

      assert %{"data" => data} =
               conn
               |> get("/names/active/gen/#{first}-#{last}")
               |> json_response(200)

      assert Enum.all?(data, fn %{"info" => %{"expire_height" => kbi}} ->
               first <= kbi and kbi <= last
             end)
    end

    test "it returns valid names on a given range, in reverse order", %{conn: conn} do
      first = 4_000_000
      last = 100_000

      assert %{"data" => data, "next" => next} =
               conn
               |> get("/names/active/gen/#{first}-#{last}")
               |> json_response(200)

      assert Enum.all?(data, fn %{"info" => %{"expire_height" => kbi}} ->
               last <= kbi and kbi <= first
             end)

      kbis =
        data |> Enum.map(fn %{"info" => %{"expire_height" => kbi}} -> kbi end) |> Enum.reverse()

      assert Enum.sort(kbis) == kbis
    end
  end

  describe "inactive_names" do
    test "get inactive names with default limit", %{conn: conn} do
      conn = get(conn, "/names/inactive")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :inactive_names, %{}, :unused_scope, 0},
          @default_limit
        )

      data = add_name_ttl(data, "auction")
      assert Enum.count(response["data"]) <= @default_limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {NameController, :inactive_names, %{}, :unused_scope, @default_limit},
          @default_limit
        )

      next_data = add_name_ttl(next_data, "auction")
      assert Enum.count(response_next["data"]) == @default_limit
      assert Jason.encode!(response_next["data"]) == Jason.encode!(next_data)
    end

    test "get inactive names with limit=6", %{conn: conn} do
      limit = 6
      conn = get(conn, "/names/inactive?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :inactive_names, %{}, :unused_scope, 0},
          limit
        )

      data = add_name_ttl(data, "auction")
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
           :unused_scope, 0},
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

      assert json_response(conn, 400) == %{"error" => "invalid direction: #{direction}"}
    end

    test "it returns valid names on a given range", %{conn: conn} do
      first = 100_000
      last = 500_000

      assert %{"data" => data, "next" => next} =
               conn
               |> get("/names/inactive/gen/#{first}-#{last}")
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

    test "it returns valid names on a given range, in reverse order", %{conn: conn} do
      first = 500_000
      last = 100_000

      assert %{"data" => data, "next" => next} =
               conn
               |> get("/names/inactive/gen/#{first}-#{last}")
               |> json_response(200)

      assert Enum.all?(data, fn %{"info" => %{"expire_height" => kbi}} ->
               last <= kbi and kbi <= first
             end)

      assert @default_limit = length(data)

      kbis =
        data |> Enum.map(fn %{"info" => %{"expire_height" => kbi}} -> kbi end) |> Enum.reverse()

      assert Enum.sort(kbis) == kbis
    end
  end

  describe "auctions" do
    test "get auctions with default limit", %{conn: conn} do
      conn = get(conn, "/names/auctions")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :auctions, %{}, :unused_scope, 0},
          @default_limit
        )

      data = add_name_ttl(data, "info")
      assert Enum.count(response["data"]) <= @default_limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)
    end

    test "get auctions with limit=2", %{conn: conn} do
      limit = 2
      conn = get(conn, "/names/auctions?limit=#{limit}")
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Cont.response_data(
          {NameController, :auctions, %{}, :unused_scope, 0},
          limit
        )

      data = add_name_ttl(data, "info")
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
          {NameController, :auctions, %{"by" => [by], "direction" => [direction]}, :unused_scope,
           0},
          limit
        )

      data = add_name_ttl(data, "info")
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

      assert json_response(conn, 400) == %{"error" => "invalid direction: #{direction}"}
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
          {NameController, :names, %{}, :unused_scope, 0},
          @default_limit
        )

      assert Enum.count(response["data"]) == @default_limit
      assert Jason.encode!(response["data"]) == Jason.encode!(data)

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      {:ok, next_data, _has_cont?} =
        Cont.response_data(
          {NameController, :names, %{}, :unused_scope, @default_limit},
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
          {NameController, :names, %{}, :unused_scope, 0},
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
          {NameController, :names, %{"by" => [by]}, :unused_scope, 0},
          limit
        )

      assert Enum.count(response["data"]) == limit
      assert response["data"] == data
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

      assert json_response(conn, 400) == %{"error" => "invalid direction: #{direction}"}
    end

    test "it returns valid names on a given range", %{conn: conn} do
      first = 100_000
      last = 500_000

      assert %{"data" => data, "next" => next} =
               conn
               |> get("/names/gen/#{first}-#{last}")
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

    test "it returns valid names on a given range, in reverse order", %{conn: conn} do
      first = 500_000
      last = 100_000

      assert %{"data" => data, "next" => next} =
               conn
               |> get("/names/gen/#{first}-#{last}")
               |> json_response(200)

      assert Enum.all?(data, fn %{"info" => %{"expire_height" => kbi}} ->
               last <= kbi and kbi <= first
             end)

      assert @default_limit = length(data)

      kbis =
        data |> Enum.map(fn %{"info" => %{"expire_height" => kbi}} -> kbi end) |> Enum.reverse()

      assert Enum.sort(kbis) == kbis
    end
  end

  describe "name" do
    test "get name info by name", %{conn: conn} do
      name = "wwwbeaconoidcom.chain"
      conn = get(conn, "/name/#{name}")

      assert json_response(conn, 200) ==
               TestUtil.handle_input(fn -> get_name(Validate.plain_name!(name)) end)
    end

    test "get name in auction with expand=true", %{conn: conn} do
      bid_key = Util.first(Model.AuctionBid)
      name = elem(bid_key, 0)
      conn = get(conn, "/name/#{name}?expand=true")

      response = json_response(conn, 200)
      name_map = TestUtil.handle_input(fn -> get_name(Validate.plain_name!(name)) end)
      name_map = update_in(name_map, ["status"], &to_string/1)

      assert name_map ==
               update_in(response, ["info", "bids"], fn bids ->
                 Enum.map(bids, & &1["tx_index"])
               end)

      assert List.first(response["info"]["bids"]) ==
               response["info"]["last_bid"] |> pop_in(["tx", "ttl"]) |> elem(1)
    end

    test "get name info by encoded hash ", %{conn: conn} do
      hash = "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj"
      conn = get(conn, "/name/#{hash}")

      assert json_response(conn, 200) ==
               TestUtil.handle_input(fn -> get_name(Validate.plain_name!(hash)) end)
    end

    test "renders error when no such name is present", %{conn: conn} do
      name = "no--such--name--in--the--chain.chain"
      conn = get(conn, "/name/#{name}")

      assert json_response(conn, 404) == %{
               "error" => TestUtil.handle_input(fn -> get_name(Validate.plain_name!(name)) end)
             }
    end
  end

  describe "pointers" do
    test "get pointers for valid given name", %{conn: conn} do
      id = "cryptodao21ae.chain"
      conn = get(conn, "/name/pointers/#{id}")

      assert json_response(conn, 200) ==
               TestUtil.handle_input(fn -> get_pointers(Validate.plain_name!(id)) end)
    end

    test "renders error when the name is missing", %{conn: conn} do
      id = "no--such--name--in--the--chain.chain"
      conn = get(conn, "/name/pointers/#{id}")

      assert json_response(conn, 404) == %{
               "error" => TestUtil.handle_input(fn -> get_pointers(Validate.plain_name!(id)) end)
             }
    end
  end

  describe "pointees" do
    test "get pointees for valid public key", %{conn: conn} do
      id = "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
      conn = get(conn, "/name/pointees/#{id}")

      assert json_response(conn, 200) ==
               TestUtil.handle_input(fn -> get_pointees(Validate.name_id!(id)) end)
    end

    test "renders error when the key is invalid", %{conn: conn} do
      id = "ak_invalidkey"
      conn = get(conn, "/name/pointees/#{id}")

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
    test "get name information for given acount/owner", %{conn: conn} do
      id = "ak_KR3a8dukEYVoZPoWFaszFgjKUpBh7J1Q5iWsz9YCamHn2rTCp"
      conn = get(conn, "/names/owned_by/#{id}")

      response = json_response(conn, 200)

      assert Jason.encode!(response) ==
               Jason.encode!(
                 TestUtil.handle_input(fn ->
                   owned_by_reply(Validate.id!(id, [:account_pubkey]), expand?(conn.params))
                 end)
               )

      assert Enum.each(response["active"], fn owned_entry ->
               expected_hash =
                 case :aens.get_name_hash(owned_entry["name"]) do
                   {:ok, name_id_bin} -> Enc.encode(:name, name_id_bin)
                   _error -> nil
                 end

               assert owned_entry["hash"] == expected_hash
             end)
    end

    test "renders error when the key is invalid", %{conn: conn} do
      id = "ak_invalid_key"
      conn = get(conn, "/names/owned_by/#{id}")

      assert json_response(conn, 400) ==
               %{
                 "error" =>
                   TestUtil.handle_input(fn ->
                     owned_by_reply(Validate.id!(id, [:account_pubkey]), expand?(conn.params))
                   end)
               }
    end
  end

  ##########

  defp get_name(name) do
    case Name.locate(name) do
      {info, source} ->
        Format.to_map(info, source)

      nil ->
        raise ErrInput.NotFound, value: name
    end
  end

  defp get_pointers(name) do
    case Name.locate(name) do
      {m_name, Model.ActiveName} ->
        Format.map_raw_values(Name.pointers(m_name), &Format.to_json/1)

      {_info, Model.InactiveName} ->
        raise ErrInput.Expired, value: name

      _not_found ->
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

  defp owned_by_reply(owner_pk, expand?) do
    %{actives: actives, top_bids: top_bids} = Name.owned_by(owner_pk)

    jsons = fn plains, source, locator ->
      for plain <- plains, reduce: [] do
        acc ->
          case locator.(plain) do
            {info, ^source} -> [Format.to_map(info, source, expand?) | acc]
            _not_found -> acc
          end
      end
    end

    actives = jsons.(actives, Model.ActiveName, &Name.locate/1)

    top_bids =
      jsons.(
        top_bids,
        Model.AuctionBid,
        &map_some(Name.locate_bid(&1), fn x -> {x, Model.AuctionBid} end)
      )

    %{"active" => actives, "top_bid" => top_bids}
  end

  defp add_name_ttl(data, field) do
    Enum.map(data, fn
      %{^field => nil} = name ->
        name

      %{^field => _auction} = name ->
        %{"auction_end" => auction_end} = Map.get(name, field)
        ttl = auction_end + :aec_governance.name_claim_max_expiration(Util.proto_vsn(auction_end))
        put_in(name, [field, "last_bid", "tx", "ttl"], ttl)
    end)
  end
end
