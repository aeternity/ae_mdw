defmodule AeMdwWeb.NameControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.EtsCache
  alias AeMdw.Validate
  alias AeMdw.Db.{Model, Name, Util}
  alias AeMdw.Db.Stream.Name, as: StreamName

  import Mock

  require AeMdw.Db.Model

  @moduletag :integration

  @default_limit 10

  describe "active_names" do
    test "get active names with default limit", %{conn: conn} do
      sample_data = %{"foo" => "bar"}
      response_data = for _i <- 1..@default_limit, do: sample_data

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn
             _tab, {_mod, _fun, _arg1, _arg2, 0} -> nil
             _tab, {_mod, _fun, _arg1, _arg2, 10} -> {response_data, :tm}
           end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           active_names: fn {:expiration, :backward}, _mapper -> response_data end
         ]}
      ] do
        assert %{"data" => ^response_data, "next" => next} =
                 conn
                 |> get("/names/active")
                 |> json_response(200)

        assert %{"data" => ^response_data} =
                 conn
                 |> get(next)
                 |> json_response(200)
      end
    end

    test "get active names with parameters by=name, direction=forward and limit=3", %{conn: conn} do
      by = "name"
      direction = "forward"
      limit = 3
      sample_data = %{"foo" => "bar"}
      response_data = for _i <- 1..limit, do: sample_data

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn _tab, _key -> nil end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           active_names: fn {:name, :forward}, _mapper -> response_data end
         ]}
      ] do
        assert %{"data" => ^response_data} =
                 conn
                 |> get("/names/active?by=#{by}&direction=#{direction}&limit=#{limit}")
                 |> json_response(200)
      end
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error = "invalid query: by=#{by}"

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [], [get: fn _tab, _key -> nil end]}
      ] do
        assert %{"error" => ^error} = conn |> get("/names/active?by=#{by}") |> json_response(400)
      end
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid query: direction=#{direction}"

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [], [get: fn _tab, _key -> nil end]}
      ] do
        assert %{"error" => ^error} =
                 conn
                 |> get("/names/active?by=#{by}&direction=#{direction}")
                 |> json_response(400)
      end
    end
  end

  describe "inactive_names" do
    test "get inactive names with default limit", %{conn: conn} do
      sample_data = %{"foo" => "bar"}
      response_data = for _i <- 1..@default_limit, do: sample_data

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn
             _tab, {_mod, _fun, _arg1, _arg2, 0} -> nil
             _tab, {_mod, _fun, _arg1, _arg2, 10} -> {response_data, :tm}
           end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           inactive_names: fn {:expiration, :backward}, _mapper -> response_data end
         ]}
      ] do
        assert %{"data" => ^response_data, "next" => next} =
                 conn
                 |> get("/names/inactive")
                 |> json_response(200)

        assert %{"data" => ^response_data} =
                 conn
                 |> get(next)
                 |> json_response(200)
      end
    end

    test "get inactive names with limit=6", %{conn: conn} do
      limit = 6
      sample_data = %{"foo" => "bar"}
      response_data = for _i <- 1..limit, do: sample_data

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn _tab, _key -> nil end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           inactive_names: fn {:expiration, :backward}, _mapper -> response_data end
         ]}
      ] do
        assert %{"data" => ^response_data} =
                 conn
                 |> get("/names/inactive?limit=#{limit}")
                 |> json_response(200)
      end
    end

    test "get inactive names with parameters by=name, direction=forward and limit=4", %{
      conn: conn
    } do
      by = "name"
      direction = "forward"
      limit = 3
      sample_data = %{"foo" => "bar"}
      response_data = for _i <- 1..limit, do: sample_data

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn _tab, _key -> nil end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           inactive_names: fn {:name, :forward}, _mapper -> response_data end
         ]}
      ] do
        assert %{"data" => ^response_data} =
                 conn
                 |> get("/names/inactive?by=#{by}&direction=#{direction}&limit=#{limit}")
                 |> json_response(200)
      end
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error = "invalid query: by=#{by}"

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [], [get: fn _tab, _key -> nil end]}
      ] do
        assert %{"error" => ^error} =
                 conn |> get("/names/inactive?by=#{by}") |> json_response(400)
      end
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid query: direction=#{direction}"

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [], [get: fn _tab, _key -> nil end]}
      ] do
        assert %{"error" => ^error} =
                 conn
                 |> get("/names/inactive?by=#{by}&direction=#{direction}")
                 |> json_response(400)
      end
    end
  end

  describe "auctions" do
    test "get auctions with default limit", %{conn: conn} do
      sample_data = %{"foo" => "bar"}
      response_data = for _i <- 1..@default_limit, do: sample_data

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn
             _tab, {_mod, _fun, _arg1, _arg2, 0} -> nil
             _tab, {_mod, _fun, _arg1, _arg2, 10} -> {response_data, :tm}
           end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           auctions: fn {:expiration, :backward}, _mapper -> response_data end
         ]}
      ] do
        assert %{"data" => ^response_data, "next" => next} =
                 conn
                 |> get("/names/auctions")
                 |> json_response(200)

        assert %{"data" => ^response_data} =
                 conn
                 |> get(next)
                 |> json_response(200)
      end
    end

    test "get auctions with limit=2", %{conn: conn} do
      limit = 2
      sample_data = %{"foo" => "bar"}
      response_data = for _i <- 1..limit, do: sample_data

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn _tab, _key -> nil end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           auctions: fn {:expiration, :backward}, _mapper -> response_data end
         ]}
      ] do
        assert %{"data" => ^response_data} =
                 conn
                 |> get("/names/auctions?limit=#{limit}")
                 |> json_response(200)
      end
    end

    test "get auctions with parameters by=expiration, direction=forward and limit=3", %{
      conn: conn
    } do
      by = "expiration"
      direction = "forward"
      limit = 3
      sample_data = %{"foo" => "bar"}
      response_data = for _i <- 1..limit, do: sample_data

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn _tab, _key -> nil end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           auctions: fn {:expiration, :forward}, _mapper -> response_data end
         ]}
      ] do
        assert %{"data" => ^response_data} =
                 conn
                 |> get("/names/auctions?by=#{by}&direction=#{direction}&limit=#{limit}")
                 |> json_response(200)
      end
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error = "invalid query: by=#{by}"

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [], [get: fn _tab, _key -> nil end]}
      ] do
        assert %{"error" => ^error} =
                 conn |> get("/names/auctions?by=#{by}") |> json_response(400)
      end
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid query: direction=#{direction}"

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [], [get: fn _tab, _key -> nil end]}
      ] do
        assert %{"error" => ^error} =
                 conn
                 |> get("/names/auctions?by=#{by}&direction=#{direction}")
                 |> json_response(400)
      end
    end
  end

  describe "names" do
    test "get active and inactive names, except those in auction, with default limit", %{
      conn: conn
    } do
      sample_data = %{"foo" => "bar"}
      response_data = for _i <- 1..@default_limit, do: sample_data

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn
             _tab, {_mod, _fun, _arg1, _arg2, 0} -> nil
             _tab, {_mod, _fun, _arg1, _arg2, 10} -> {response_data, :tm}
           end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           active_names: fn {:expiration, :backward}, _mapper -> response_data end,
           inactive_names: fn {:expiration, :backward}, _mapper -> response_data end
         ]}
      ] do
        assert %{"data" => ^response_data, "next" => next} =
                 conn
                 |> get("/names")
                 |> json_response(200)

        assert %{"data" => ^response_data} =
                 conn
                 |> get(next)
                 |> json_response(200)
      end
    end

    test "get active and inactive names, except those in auction, with limit=2", %{conn: conn} do
      limit = 2
      sample_data = %{"foo" => "bar"}

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn _tab, _key -> nil end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           active_names: fn {:expiration, :backward}, _mapper -> [sample_data] end,
           inactive_names: fn {:expiration, :backward}, _mapper -> [sample_data] end
         ]}
      ] do
        assert %{"data" => [^sample_data, ^sample_data]} =
                 conn
                 |> get("/names?limit=#{limit}")
                 |> json_response(200)
      end
    end

    test "get active and inactive names, except those in auction, with parameters by=name, direction=forward and limit=4",
         %{conn: conn} do
      limit = 4
      by = "name"
      direction = "forward"
      sample_data = %{"foo" => "bar"}

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [],
         [
           get: fn _tab, _key -> nil end,
           put: fn _tab, _key, _val -> nil end
         ]},
        {StreamName, [],
         [
           active_names: fn {:name, :forward}, _mapper -> [sample_data, sample_data] end,
           inactive_names: fn {:name, :forward}, _mapper -> [sample_data, sample_data] end
         ]}
      ] do
        assert %{"data" => [^sample_data, ^sample_data]} =
                 conn
                 |> get("/names?by=#{by}&direction=#{direction}&limit=#{limit}")
                 |> json_response(200)
      end
    end

    test "renders error when parameter by is invalid", %{conn: conn} do
      by = "invalid_by"
      error = "invalid query: by=#{by}"

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [], [get: fn _tab, _key -> nil end]}
      ] do
        assert %{"error" => ^error} = conn |> get("/names?by=#{by}") |> json_response(400)
      end
    end

    test "renders error when parameter direction is invalid", %{conn: conn} do
      by = "name"
      direction = "invalid_direction"
      error = "invalid query: direction=#{direction}"

      with_mocks [
        {Util, [:passthrough], last_gen: fn -> 20 end},
        {EtsCache, [], [get: fn _tab, _key -> nil end]}
      ] do
        assert %{"error" => ^error} =
                 conn |> get("/names?by=#{by}&direction=#{direction}") |> json_response(400)
      end
    end
  end

  describe "name" do
    test "get name info by name", %{conn: conn} do
      name = "wwwbeaconoidcom.chain"
      own_original = <<>>
      own_current = <<>>

      with_mocks [
        {Name, [],
         [
           locate: fn ^name ->
             {Model.name(index: name, active: true, expire: 0), Model.ActiveName}
           end,
           locate_bid: fn ^name -> nil end,
           pointers: fn _name_model -> %{} end,
           ownership: fn _name_model -> %{original: own_original, current: own_current} end
         ]}
      ] do
        assert %{
                 "name" => ^name,
                 "active" => true,
                 "info" => %{
                   "ownership" => %{"current" => ^own_current, "original" => ^own_original}
                 }
               } = conn |> get("/name/#{name}") |> json_response(200)
      end
    end

    test "get name info by encoded hash ", %{conn: conn} do
      hash = "nm_MwcgT7ybkVYnKFV6bPqhwYq2mquekhZ2iDNTunJS2Rpz3Njuj"
      hash_id = Validate.id!(hash)
      name = "some-name.chain"

      with_mocks [
        {Name, [],
         [
           plain_name: fn ^hash_id -> {:ok, name} end,
           locate: fn ^name ->
             {Model.name(index: name, active: true, expire: 0), Model.ActiveName}
           end,
           locate_bid: fn ^name -> nil end,
           pointers: fn _name_model -> %{} end,
           ownership: fn _name -> %{original: <<>>, current: <<>>} end
         ]}
      ] do
        assert %{"active" => true, "name" => ^name} =
                 conn |> get("/name/#{hash}") |> json_response(200)
      end
    end

    test "renders error when no such name is present", %{conn: conn} do
      name = "no--such--name--in--the--chain.chain"
      error = "not found: #{name}"

      with_mocks [{Name, [], [locate: fn ^name -> nil end]}] do
        assert %{"error" => ^error} = conn |> get("/name/#{name}") |> json_response(404)
      end
    end
  end

  describe "pointers" do
    test "get pointers for valid given name", %{conn: conn} do
      id = "wwwbeaconoidcom.chain"
      some_reply = %{"foo" => "bar"}

      with_mocks [
        {Name, [],
         [
           locate: fn ^id ->
             {Model.name(index: id, active: true, expire: 0), Model.ActiveName}
           end,
           pointers: fn _name_model -> some_reply end
         ]}
      ] do
        assert ^some_reply = conn |> get("/name/pointers/#{id}") |> json_response(200)
      end
    end

    test "renders error when the name is missing", %{conn: conn} do
      id = "no--such--name--in--the--chain.chain"
      error = "not found: #{id}"

      with_mocks [{Name, [], [locate: fn ^id -> nil end]}] do
        assert %{"error" => ^error} = conn |> get("/name/pointers/#{id}") |> json_response(404)
      end
    end
  end

  describe "pointees" do
    test "get pointees for valid public key", %{conn: conn} do
      id = "ak_2HNsyfhFYgByVq8rzn7q4hRbijsa8LP1VN192zZwGm1JRYnB5C"
      name_id = Validate.name_id!(id)
      active_pointees = [%{"foo" => "active"}]
      inactive_pointees = [%{"foo" => "inactive"}]

      with_mocks [
        {Name, [], [pointees: fn ^name_id -> {active_pointees, inactive_pointees} end]}
      ] do
        assert %{"active" => ^active_pointees, "inactive" => ^inactive_pointees} =
                 conn
                 |> get("/name/pointees/#{id}")
                 |> json_response(200)
      end
    end

    test "renders error when the key is invalid", %{conn: conn} do
      id = "ak_invalidkey"
      error = "invalid id: #{id}"

      assert %{"error" => ^error} = conn |> get("/name/pointees/#{id}") |> json_response(400)
    end
  end

  describe "owned_by" do
    test "get name information for given acount/owner", %{conn: conn} do
      id = "ak_2VMBcnJQgzQQeQa6SgCgufYiRqgvoY9dXHR11ixqygWnWGfSah"
      owner_id = Validate.id!(id)

      with_mocks [{Name, [], [owned_by: fn ^owner_id -> %{actives: [], top_bids: []} end]}] do
        assert %{"active" => [], "top_bid" => []} =
                 conn |> get("/names/owned_by/#{id}") |> json_response(200)
      end
    end

    test "renders error when the key is invalid", %{conn: conn} do
      id = "ak_invalid_key"
      error = "invalid id: #{id}"

      assert %{"error" => ^error} = conn |> get("/names/owned_by/#{id}") |> json_response(400)
    end
  end
end
