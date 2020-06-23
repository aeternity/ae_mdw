defmodule AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Validate
  alias AeMdw.Db.Util
  alias AeMdwWeb.TxController

  @default_limit 10

  describe "tx" do
    # The test will work only for mainnet, because the tx hash is hardcoded and valid only for mainnet network
    test "get a transaction by a given hash", %{conn: conn} do
      valid_hash = "th_zATv7B4RHS45GamShnWgjkvcrQfZUWQkZ8gk1RD4m2uWLJKnq"
      conn = get(conn, "/tx/#{valid_hash}")

      assert json_response(conn, 200)["hash"] == valid_hash
    end

    test "renders errors when data is invalid", %{conn: conn} do
      invalid_hash = "some_invalid_hash"
      conn = get(conn, "/tx/#{invalid_hash}")

      assert json_response(conn, 400) == %{"error" => "invalid id: #{invalid_hash}"}
    end
  end

  describe "txi" do
    test "get a transaction by a given index", %{conn: conn} do
      valid_index = 10_000_000
      conn = get(conn, "/txi/#{valid_index}")

      assert json_response(conn, 200)["tx_index"] == valid_index
    end

    test "renders errors when data is invalid", %{conn: conn} do
      invalid_index = -10_000_000
      conn = get(conn, "/txi/#{invalid_index}")

      assert json_response(conn, 400) == %{
               "error" => "invalid non-negative integer: #{invalid_index}"
             }
    end

    test "renders errors when data is not found", %{conn: conn} do
      index = 90_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000
      conn = get(conn, "/txi/#{index}")

      assert json_response(conn, 404) == %{"error" => "no such transaction"}
    end
  end

  describe "count" do
    test "get count of transactions at the current height", %{conn: conn} do
      conn = get(conn, "/txs/count")

      assert json_response(conn, 200) == Util.last_txi()
    end
  end

  describe "count_id" do
    # The test will work only for mainnet, because the account id is hardcoded and valid only for mainnet network
    test "get transactions count and its type for given aeternity ID", %{conn: conn} do
      id = "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"
      conn = get(conn, "/txs/count/#{id}")

      assert json_response(conn, 200) ==
               Validate.id!(id) |> TxController.id_counts() |> keys_to_string()
    end

    test "renders errors when data is invalid", %{conn: conn} do
      invalid_id = "some_invalid_id"
      conn = get(conn, "/txs/count/#{invalid_id}")

      assert json_response(conn, 400) == %{"error" => "invalid id: #{invalid_id}"}
    end
  end

  describe "txs_direction with type parameter" do
    # Tests with direction `forward` and different `type` parameters
    test "get transaction with direction=forward and type parameter=channel_create", %{conn: conn} do
      limit = "4"
      type = "channel_create"
      conn = get(conn, "/txs/forward?type=#{type}&limit=#{limit}")

      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == String.to_integer(limit)

      Enum.each(response["data"], fn data ->
        assert data["tx"]["type"] == transform_tx_name(type)
      end)

      # There is a problem with next!!!

      # conn_next = get(conn, response["next"])

      # response_next = json_response(conn_next, 200)

      # assert Enum.count(response_next["data"]) == String.to_integer(limit)

      # Enum.each(response_next["data"], fn data_next ->
      #   assert data_next["tx"]["type"] == transform_tx_name(type)
      # end)
    end

    test "get transaction with direction=forward and type parameter=spend", %{conn: conn} do
      limit = "15"
      type = "spend"
      conn = get(conn, "/txs/forward?type=#{type}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] == transform_tx_name(type)
      end)
    end

    test "get transaction with direction=forward and type parameter=name_claim", %{conn: conn} do
      limit = "19"
      type = "name_claim"
      conn = get(conn, "/txs/forward?type=#{type}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) <= String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] == transform_tx_name(type)
      end)
    end

    test "get transaction with direction=forward and type parameter=name_preclaim with default limit",
         %{conn: conn} do
      type = "name_preclaim"
      conn = get(conn, "/txs/forward?type=#{type}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == @default_limit

      Enum.each(response, fn data ->
        assert data["tx"]["type"] == transform_tx_name(type)
      end)
    end

    # Tests with direction `backward` and different `type` parameters
    test "get transaction with direction=backward and type parameter=spend with default limit", %{
      conn: conn
    } do
      type = "spend"
      conn = get(conn, "/txs/backward?type=#{type}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == @default_limit

      Enum.each(response, fn data ->
        assert data["tx"]["type"] == transform_tx_name(type)
      end)
    end

    test "get transaction with direction=backward and type parameter=contract_create", %{
      conn: conn
    } do
      limit = "19"
      type = "contract_create"
      conn = get(conn, "/txs/backward?type=#{type}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] == transform_tx_name(type)
      end)
    end

    test "get transaction with direction=backward and type parameter=oracle_query", %{conn: conn} do
      limit = "15"
      type = "oracle_query"
      conn = get(conn, "/txs/backward?type=#{type}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] == transform_tx_name(type)
      end)
    end

    test "renders errors when type parameter is invalid", %{conn: conn} do
      invalid_type = "some_invalid_type"
      conn = get(conn, "/txs/forward?type=#{invalid_type}")

      assert json_response(conn, 400) == %{"error" => "invalid transaction type: #{invalid_type}"}
    end

    test "renders errors when direction is invalid", %{conn: conn} do
      invalid_direction = "back"
      conn = get(conn, "/txs/#{invalid_direction}")

      assert json_response(conn, 400) == %{"error" => "invalid direction: #{invalid_direction}"}
    end
  end

  describe "txs_direction with type_group parameter" do
    # Tests with direction `forward` and different `type_group` parameters
    test "get transaction with direction=forward and type_group parameter=oracle", %{conn: conn} do
      limit = "18"
      type_group = "oracle"

      conn = get(conn, "/txs/forward?type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group)
      end)
    end

    test "get transaction with direction=forward and type_group parameter=contract", %{conn: conn} do
      limit = "45"
      type_group = "contract"

      conn = get(conn, "/txs/forward?type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group)
      end)
    end

    test "get transaction with direction=forward and type_group parameter=ga", %{conn: conn} do
      limit = "7"
      type_group = "ga"

      conn = get(conn, "/txs/forward?type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group)
      end)
    end

    test "get transaction with direction=forward and type_group parameter=channel", %{conn: conn} do
      limit = "22"
      type_group = "channel"

      conn = get(conn, "/txs/forward?type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group)
      end)
    end

    # Tests with direction `backward` and different `type_group` parameters
    test "get transaction with direction=backward and type_group parameter=channel", %{conn: conn} do
      limit = "12"
      type_group = "channel"

      conn = get(conn, "/txs/backward?type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group)
      end)
    end

    test "get transaction with direction=backward and type_group parameter=oracle with default limit",
         %{conn: conn} do
      type_group = "oracle"

      conn = get(conn, "/txs/backward?type_group=#{type_group}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == @default_limit

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group)
      end)
    end

    test "get transaction with direction=backward and type_group parameter=contract", %{
      conn: conn
    } do
      limit = "15"
      type_group = "contract"

      conn = get(conn, "/txs/backward?type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group)
      end)
    end

    test "get transaction with direction=backward and type_group parameter=ga", %{conn: conn} do
      limit = "9"
      type_group = "ga"

      conn = get(conn, "/txs/backward?type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) <= String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group)
      end)
    end

    test "get transaction with direction=backward and type_group parameter=name", %{conn: conn} do
      limit = "35"
      type_group = "name"

      conn = get(conn, "/txs/backward?type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group)
      end)
    end

    test "get transaction with direction=backward and type_group parameter=spend", %{conn: conn} do
      limit = "33"
      type_group = "spend"

      conn = get(conn, "/txs/backward?type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group)
      end)
    end

    test "renders errors when type_group parameter is invalid", %{conn: conn} do
      invalid_type_group = "some_invalid_type_group"
      conn = get(conn, "/txs/backward?type_group=#{invalid_type_group}")

      assert json_response(conn, 400) == %{
               "error" => "invalid transaction group: #{invalid_type_group}"
             }
    end
  end

  describe "txs_direction with type and type_group parameter" do
    # Tests with direction `forward` and different `type` and `type_group` parameters
    test "get transaction with direction=forward, type=name_claim and type_group=oracle", %{
      conn: conn
    } do
      limit = "15"
      type_group = "oracle"
      type = "name_claim"
      conn = get(conn, "/txs/forward?type=#{type}&type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group) || transform_tx_name(type)
      end)
    end

    test "get transaction with direction=forward, type=contract_create and type_group=channel", %{
      conn: conn
    } do
      limit = "38"
      type_group = "channel"
      type = "contract_create"
      conn = get(conn, "/txs/forward?type=#{type}&type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group) || transform_tx_name(type)
      end)
    end

    test "get transaction with direction=forward, type=spend and type_group=ga", %{conn: conn} do
      type_group = "ga"
      type = "spend"
      conn = get(conn, "/txs/forward?type=#{type}&type_group=#{type_group}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == @default_limit

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group) || transform_tx_name(type)
      end)
    end

    # Tests with direction `backward` and different `type` and `type_group` parameters
    test "get transaction with direction=backward, type=contract_call and type_group=oracle", %{
      conn: conn
    } do
      limit = "31"
      type_group = "oracle"
      type = "contract_call"
      conn = get(conn, "/txs/backward?type=#{type}&type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group) || transform_tx_name(type)
      end)
    end

    test "get transaction with direction=backward, type=channel_close_solo and type_group=name",
         %{
           conn: conn
         } do
      limit = "18"
      type_group = "name"
      type = "channel_close_solo"
      conn = get(conn, "/txs/backward?type=#{type}&type_group=#{type_group}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group) || transform_tx_name(type)
      end)
    end

    test "get transaction with direction=backward, type=oracle_register and type_group=spend with default limit",
         %{conn: conn} do
      type_group = "spend"
      type = "oracle_register"
      conn = get(conn, "/txs/backward?type=#{type}&type_group=#{type_group}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == @default_limit

      Enum.each(response, fn data ->
        assert data["tx"]["type"] in check_tx_group(type_group) || transform_tx_name(type)
      end)
    end

    test "renders errors when type_group parameter is invalid", %{conn: conn} do
      invalid_type_group = "some_invalid_type_group"
      type = "spend"
      conn = get(conn, "/txs/forward?type=#{type}&type_group=#{invalid_type_group}")

      assert json_response(conn, 400) == %{
               "error" => "invalid transaction group: #{invalid_type_group}"
             }
    end

    test "renders errors when type parameter is invalid", %{conn: conn} do
      type_group = "channel"
      invalid_type = "some_invalid_type"
      conn = get(conn, "/txs/forward?type=#{invalid_type}&type_group=#{type_group}")

      assert json_response(conn, 400) == %{
               "error" => "invalid transaction type: #{invalid_type}"
             }
    end
  end

  # These tests will work only for mainnet, because of the hardcoded IDs and they are valid only for mainnet network
  describe "txs_direction with generic id parameter" do
    # Tests with direction `forward` and different `id` parameters
    test "get transaction with direction=forward and given account ID", %{conn: conn} do
      limit = "28"
      criteria = "account"

      <<_prefix::3-binary, rest::binary>> =
        id = "ak_26ubrEL8sBqYNp4kvKb1t4Cg7XsCciYq4HdznrvfUkW359gf17"

      conn = get(conn, "/txs/forward?#{criteria}=#{id}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert id_exists?(data["tx"], rest)
      end)
    end

    test "get transaction with direction=forward and given contract ID with default limit", %{
      conn: conn
    } do
      criteria = "contract"

      <<_prefix::3-binary, rest::binary>> =
        id = "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"

      conn = get(conn, "/txs/forward?#{criteria}=#{id}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == @default_limit

      Enum.each(response, fn data ->
        assert id_exists?(data["tx"], rest)
        assert data["tx"]["type"] in check_tx_group(criteria)
      end)
    end

    test "get transaction with direction=forward and given oracle ID with default limit", %{
      conn: conn
    } do
      criteria = "oracle"

      <<_prefix::3-binary, rest::binary>> =
        id = "ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"

      conn = get(conn, "/txs/forward?#{criteria}=#{id}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == @default_limit

      Enum.each(response, fn data ->
        assert id_exists?(data["tx"], rest)
        assert data["tx"]["type"] in check_tx_group(criteria)
      end)
    end

    # Tests with direction `backward` and different `id` parameters
    test "get transaction with direction=backward and given account ID", %{conn: conn} do
      limit = "38"
      criteria = "account"

      <<_prefix::3-binary, rest::binary>> =
        id = "ak_wTPFpksUJFjjntonTvwK4LJvDw11DPma7kZBneKbumb8yPeFq"

      conn = get(conn, "/txs/backward?#{criteria}=#{id}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert id_exists?(data["tx"], rest)
      end)
    end

    test "get transaction with direction=backward and given contract ID with default limit", %{
      conn: conn
    } do
      criteria = "contract"

      <<_prefix::3-binary, rest::binary>> =
        id = "ct_2rtXsV55jftV36BMeR5gtakN2VjcPtZa3PBURvzShSYWEht3Z7"

      conn = get(conn, "/txs/backward?#{criteria}=#{id}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == @default_limit

      Enum.each(response, fn data ->
        assert id_exists?(data["tx"], rest)
        assert data["tx"]["type"] in check_tx_group(criteria)
      end)
    end

    test "get transaction with direction=backward and given oracle ID with default limit", %{
      conn: conn
    } do
      criteria = "oracle"

      <<_prefix::3-binary, rest::binary>> =
        id = "ok_28QDg7fkF5qiKueSdUvUBtCYPJdmMEoS73CztzXCRAwMGKHKZh"

      conn = get(conn, "/txs/backward?#{criteria}=#{id}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == @default_limit

      Enum.each(response, fn data ->
        assert id_exists?(data["tx"], rest)
        assert data["tx"]["type"] in check_tx_group(criteria)
      end)
    end

    test "renders errors when transaction with direction=forward and invalid ID", %{conn: conn} do
      id = "some_invalid_key"
      conn = get(conn, "/txs/forward?account=#{id}")

      assert json_response(conn, 400) == %{"error" => "invalid id: #{id}"}
    end

    test "renders errors when transaction with direction=forward and the ID is valid, but not pass correctly ",
         %{conn: conn} do
      id = "ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"
      # the oracle id is valid but is passed as account id, which is not correct
      conn = get(conn, "/txs/backward?account=#{id}")

      assert json_response(conn, 400) == %{"error" => "invalid id: #{id}"}
    end
  end

  # These tests will work only for mainnet, because of the hardcoded IDs and they are valid only for mainnet network
  describe "txs_direction with transaction fields" do
    test "get transaction with direction=forward, tx_type=contract_call and field=caller_id ", %{
      conn: conn
    } do
      limit = "8"
      tx_type = "contract_call"
      field = "caller_id"
      id = "ak_YCwfWaW5ER6cRsG9Jg4KMyVU59bQkt45WvcnJJctQojCqBeG2"
      conn = get(conn, "/txs/forward?#{tx_type}.#{field}=#{id}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) <= String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["caller_id"] == id
      end)
    end

    test "get transaction with direction=forward, tx_type=channel_create and field=initiator_id ",
         %{conn: conn} do
      limit = "5"
      tx_type = "channel_create"
      field = "initiator_id"
      id = "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS"
      conn = get(conn, "/txs/forward?#{tx_type}.#{field}=#{id}&limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) <= String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx"]["initiator_id"] == id
      end)
    end

    test "get transaction with direction=forward, tx_type=ga_attach and field=owner_id ",
         %{conn: conn} do
      tx_type = "ga_attach"
      field = "owner_id"
      id = "ak_2RUVa9bvHUD8wYSrvixRjy9LonA9L29wRvwDfQ4y37ysMKjgdQ"
      conn = get(conn, "/txs/forward?#{tx_type}.#{field}=#{id}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) <= @default_limit

      Enum.each(response, fn data ->
        assert data["tx"]["owner_id"] == id
      end)
    end

    test "get transaction with direction=forward, tx_type=spend and field=recipient_id ",
         %{conn: conn} do
      tx_type = "spend"
      field = "recipient_id"
      id = "ak_wTPFpksUJFjjntonTvwK4LJvDw11DPma7kZBneKbumb8yPeFq"
      conn = get(conn, "/txs/forward?#{tx_type}.#{field}=#{id}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) <= @default_limit

      Enum.each(response, fn data ->
        assert data["tx"]["recipient_id"] == id
      end)
    end

    test "get transaction with direction=forward, tx_type=oracle_query and field=sender_id ",
         %{conn: conn} do
      tx_type = "oracle_query"
      field = "sender_id"
      id = "ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b"
      conn = get(conn, "/txs/forward?#{tx_type}.#{field}=#{id}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) <= @default_limit

      Enum.each(response, fn data ->
        assert data["tx"]["sender_id"] == id
      end)
    end

    test "renders errors when transaction with direction=forward, tx_type=oracle_query and given field is wrong ",
         %{conn: conn} do
      tx_type = "oracle_query"
      field = "account_id"
      id = "ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b"
      conn = get(conn, "/txs/forward?#{tx_type}.#{field}=#{id}")

      assert json_response(conn, 400) == %{"error" => "invalid transaction field: :#{field}"}
    end

    test "renders errors when transaction with direction=forward, tx_type and field are invalid ",
         %{conn: conn} do
      tx_type = "invalid"
      field = "account_id"
      id = "ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b"
      conn = get(conn, "/txs/forward?#{tx_type}.#{field}=#{id}")

      assert json_response(conn, 400) == %{"error" => "invalid transaction type: #{tx_type}"}
    end
  end

  describe "txs_range bounded by generation" do
    test "get transaction with scope=gen at certain height and continuation", %{conn: conn} do
      height = "273000"
      conn = get(conn, "/txs/gen/#{height}")

      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == @default_limit

      Enum.each(response["data"], fn data ->
        assert data["block_height"] == String.to_integer(height)
      end)

      conn_next = get(conn, response["next"])

      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == @default_limit

      Enum.each(response_next["data"], fn data_next ->
        assert data_next["block_height"] == String.to_integer(height)
      end)
    end

    test "get transaction with scope=gen at certain range and continuation", %{conn: conn} do
      height_from = "197000"
      height_to = "197003"
      limit = "50"
      conn = get(conn, "/txs/gen/#{height_from}-#{height_to}?limit=#{limit}")

      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == String.to_integer(limit)

      Enum.each(response["data"], fn data ->
        assert data["block_height"] in String.to_integer(height_from)..String.to_integer(
                 height_to
               )
      end)

      # get next data
      conn_next = get(conn, response["next"])

      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == String.to_integer(limit)

      Enum.each(response_next["data"], fn data_next ->
        assert data_next["block_height"] in String.to_integer(height_from)..String.to_integer(
                 height_to
               )
      end)
    end

    test "renders errors when transaction with scope=gen with a valid range and random access", %{
      conn: conn
    } do
      height_from = "223000"
      height_to = "223007"
      limit = "15"
      page = "6"

      conn = get(conn, "/txs/gen/#{height_from}-#{height_to}?limit=#{limit}&page=#{page}")

      assert json_response(conn, 400) == %{"error" => "random access not supported"}
    end

    test "renders errors when is passed invalid scope", %{conn: conn} do
      height_from = "223000"
      height_to = "223007"

      conn = get(conn, "/txs/invalid_scope/#{height_from}-#{height_to}")

      assert json_response(conn, 400) == %{"error" => "invalid scope: invalid_scope"}
    end

    test "renders errors when is passed invalid range", %{conn: conn} do
      invalid_range = "invalid_range"

      conn = get(conn, "/txs/gen/#{invalid_range}")

      assert json_response(conn, 400) == %{"error" => "invalid range: #{invalid_range}"}
    end
  end

  describe "txs_range bounded by transaction index" do
    test "get transaction with scope=txi and transaction index", %{conn: conn} do
      index = "605999"

      conn = get(conn, "/txs/txi/#{index}")

      response = json_response(conn, 200)["data"]

      Enum.each(response, fn data ->
        assert data["tx_index"] == String.to_integer(index)
      end)
    end

    test "get transaction with scope=txi and in a range transaction indexes", %{conn: conn} do
      index_from = "700000"
      index_to = "700025"
      limit = "25"

      conn = get(conn, "/txs/txi/#{index_from}-#{index_to}?limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == String.to_integer(limit)

      Enum.each(response, fn data ->
        assert data["tx_index"] in String.to_integer(index_from)..String.to_integer(index_to)
      end)
    end

    test "renders errors when is passed invalid index", %{conn: conn} do
      invalid_index = "invalid_index"

      conn = get(conn, "/txs/txi/#{invalid_index}")

      assert json_response(conn, 400) == %{"error" => "invalid range: #{invalid_index}"}
    end
  end

  # =====================================

  defp transform_tx_name(name), do: Validate.tx_type!(name) |> AeMdw.Node.tx_name()

  defp keys_to_string(map) when is_map(map) do
    for {key, val} <- map, into: %{}, do: {to_string(key), keys_to_string(val)}
  end

  defp keys_to_string(value), do: value

  defp check_tx_group(tx_group) do
    String.to_atom(tx_group) |> AeMdw.Node.tx_group() |> Enum.map(&AeMdw.Node.tx_name/1)
  end

  defp remove_prefix(<<_prefix::3-binary, rest::binary>>), do: rest
  defp remove_prefix(_), do: false

  defp id_exists?(tx, id),
    do:
      remove_prefix(tx["recipient_id"]) ||
        remove_prefix(tx["sender_id"]) ||
        remove_prefix(tx["owner_id"]) ||
        remove_prefix(tx["caller_id"]) ||
        remove_prefix(tx["channel_id"]) ||
        remove_prefix(tx["from_id"]) ||
        remove_prefix(tx["initiator_id"]) ||
        remove_prefix(tx["responder_id"]) ||
        remove_prefix(tx["to_id"]) ||
        remove_prefix(tx["ga_id"]) ||
        remove_prefix(tx["commitment_id"]) ||
        remove_prefix(tx["account_id"]) ||
        remove_prefix(tx["name_id"]) ||
        remove_prefix(tx["oracle_id"]) ||
        remove_prefix(tx["payer_id"]) == id
end
