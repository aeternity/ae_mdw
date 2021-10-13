defmodule Integration.AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag :integration

  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Util
  alias AeMdwWeb.Continuation
  alias AeMdwWeb.TxController
  alias :aeser_api_encoder, as: Enc
  alias AeMdwWeb.Util, as: WebUtil
  alias Plug.Conn

  require Model

  @type_spend_tx "SpendTx"

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
      valid_index = 15_499_122
      conn = get(conn, "/txi/#{valid_index}")

      assert json_response(conn, 200)["tx_index"] == valid_index
      assert tx = json_response(conn, 200)["tx"]
      assert tx["type"] == "ContractCreateTx"
      assert tx["gas_used"] && tx["gas_used"] > 0
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
               id |> Validate.id!() |> TxController.id_counts() |> keys_to_string()
    end

    test "renders errors when data is invalid", %{conn: conn} do
      invalid_id = "some_invalid_id"
      conn = get(conn, "/txs/count/#{invalid_id}")

      assert json_response(conn, 400) == %{"error" => "invalid id: #{invalid_id}"}
    end
  end

  describe "txs_direction only with direction" do
    test "get transactions when direction=forward", %{conn: conn} do
      limit = 33
      conn = get(conn, "/txs/forward?limit=#{limit}")
      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == limit

      Enum.each(response["data"], fn data ->
        assert data["tx_index"] in 0..(limit - 1)
      end)

      {:ok, data, _has_cont?} =
        Continuation.response_data({TxController, :txs, %{}, conn.assigns.scope, 0}, limit)

      assert ^data = response["data"]

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == limit

      Enum.each(response_next["data"], fn data_next ->
        assert data_next["tx_index"] in (limit - 1)..((limit - 1) * (limit - 1))
      end)

      {:ok, data_next, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn_next), conn_next.assigns.scope, limit},
          limit
        )

      assert ^data_next = response_next["data"]
    end

    test "get transactions when direction=backward", %{conn: conn} do
      limit = 24
      conn = get(conn, "/txs/backward?limit=#{limit}")
      response = json_response(conn, 200)

      assert Enum.count(response["data"]) == limit

      Enum.each(response["data"], fn data ->
        assert data["tx_index"] in Util.last_txi()..(Util.last_txi() - limit)
      end)

      {:ok, data, _has_cont?} =
        Continuation.response_data({TxController, :txs, %{}, conn.assigns.scope, 0}, limit)

      assert ^data = response["data"]

      conn_next = get(conn, response["next"])
      response_next = json_response(conn_next, 200)

      assert Enum.count(response_next["data"]) == limit

      Enum.each(response_next["data"], fn data_next ->
        assert data_next["tx_index"] in (Util.last_txi() - limit)..(Util.last_txi() -
                                                                      limit * limit)
      end)

      {:ok, next_data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn_next), conn_next.assigns.scope, limit},
          limit
        )

      assert ^next_data = response_next["data"]
    end

    test "renders errors when direction is invalid", %{conn: conn} do
      invalid_direction = "back"
      conn = get(conn, "/txs/#{invalid_direction}")

      assert json_response(conn, 400) == %{"error" => "invalid direction: #{invalid_direction}"}
    end
  end

  describe "txs_direction with given type parameter" do
    # Tests with direction is `forward` and different `type` parameters
    test "get transactions when direction=forward and type parameter=channel_create", %{
      conn: conn
    } do
      limit = 4
      type = "channel_create"
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "forward", "type", type, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], transform_tx_type, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(transform_tx_type, limit)
    end

    test "get transactions when direction=forward and type parameter=spend", %{conn: conn} do
      limit = 15
      type = "spend"
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "forward", "type", type, limit)
      response = json_response(conn, 200)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      check_response_data(response["data"], transform_tx_type, limit)

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(transform_tx_type, limit)
    end

    test "get transactions when direction=forward and type parameter=name_claim", %{conn: conn} do
      limit = 19
      type = "name_claim"
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "forward", "type", type, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], transform_tx_type, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(transform_tx_type, limit)
    end

    test "get transactions when direction=forward and type parameter=name_preclaim with default limit",
         %{conn: conn} do
      type = "name_preclaim"
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "forward", "type", type)
      response = json_response(conn, 200)

      check_response_data(response["data"], transform_tx_type, @default_limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(transform_tx_type, @default_limit)
    end

    # Tests when direction is `backward` and different `type` parameters
    test "get transactions when direction=backward and type parameter=spend with default limit",
         %{
           conn: conn
         } do
      type = "spend"
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "backward", "type", type)
      response = json_response(conn, 200)

      check_response_data(response["data"], transform_tx_type, @default_limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(transform_tx_type, @default_limit)
    end

    test "get transactions when direction=backward and type parameter=contract_create", %{
      conn: conn
    } do
      limit = 19
      type = "contract_create"
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "backward", "type", type, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], transform_tx_type, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(transform_tx_type, limit)
    end

    test "get transactions when direction=backward and type parameter=oracle_query", %{conn: conn} do
      limit = 15
      type = "oracle_query"
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "backward", "type", type, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], transform_tx_type, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(transform_tx_type, limit)
    end

    test "renders errors when type parameter is invalid", %{conn: conn} do
      invalid_type = "some_invalid_type"
      conn = get(conn, "/txs/forward?type=#{invalid_type}")

      assert json_response(conn, 400) == %{"error" => "invalid transaction type: #{invalid_type}"}
    end
  end

  describe "txs_direction with given type_group parameter" do
    # Tests when direction is `forward` and different `type_group` parameters
    test "get transactions when direction=forward and type_group parameter=oracle", %{conn: conn} do
      limit = 18
      type_group = "oracle"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn = request_txs(conn, "forward", "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, limit)
    end

    test "get transactions when direction=forward and type_group parameter=contract", %{
      conn: conn
    } do
      limit = 45
      type_group = "contract"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn = request_txs(conn, "forward", "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, limit)
    end

    test "get transactions when direction=forward and type_group parameter=ga", %{conn: conn} do
      limit = 2
      type_group = "ga"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn = request_txs(conn, "forward", "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, limit)
    end

    test "get transactions when direction=forward and type_group parameter=channel", %{conn: conn} do
      limit = 22
      type_group = "channel"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn = request_txs(conn, "forward", "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, limit)
    end

    # Tests when direction is `backward` and different `type_group` parameters
    test "get transactions when direction=backward and type_group parameter=channel", %{
      conn: conn
    } do
      limit = 12
      type_group = "channel"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn = request_txs(conn, "backward", "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, limit)
    end

    test "get transactions when direction=backward and type_group parameter=oracle with default limit",
         %{conn: conn} do
      type_group = "oracle"

      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn = request_txs(conn, "backward", "type_group", type_group)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, @default_limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, @default_limit)
    end

    test "get transactions when direction=backward and type_group parameter=contract", %{
      conn: conn
    } do
      limit = 15
      type_group = "contract"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn = request_txs(conn, "backward", "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, limit)
    end

    test "get transactions when direction=backward and type_group parameter=ga", %{conn: conn} do
      limit = 3
      type_group = "ga"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn = request_txs(conn, "backward", "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, limit)

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, limit)
    end

    test "get transactions when direction=backward and type_group parameter=name", %{conn: conn} do
      limit = 35
      type_group = "name"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn = request_txs(conn, "backward", "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, limit)
    end

    test "get transactions when direction=backward and type_group parameter=spend", %{conn: conn} do
      limit = 33
      type_group = "spend"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn = request_txs(conn, "backward", "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, limit)
    end

    test "renders errors when type_group parameter is invalid", %{conn: conn} do
      invalid_type_group = "some_invalid_type_group"
      conn = get(conn, "/txs/backward?type_group=#{invalid_type_group}")

      assert json_response(conn, 400) == %{
               "error" => "invalid transaction group: #{invalid_type_group}"
             }
    end
  end

  describe "txs_direction with given type and type_group parameters" do
    # Tests when direction is `forward` and different `type` and `type_group` parameters
    test "get transactions when direction=forward, type=name_claim and type_group=oracle", %{
      conn: conn
    } do
      limit = 15
      type_group = "oracle"
      type = "name_claim"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "forward", "type", type, "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, transform_tx_type, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, transform_tx_type, limit)
    end

    test "get transactions when direction=forward, type=contract_create and type_group=channel",
         %{
           conn: conn
         } do
      limit = 38
      type_group = "channel"
      type = "contract_create"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "forward", "type", type, "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, transform_tx_type, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, transform_tx_type, limit)
    end

    test "get transactions when direction=forward, type=spend and type_group=ga", %{conn: conn} do
      type_group = "ga"
      type = "spend"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "forward", "type", type, "type_group", type_group)
      response = json_response(conn, 200)

      check_response_data(
        response["data"],
        txs_types_by_tx_group,
        transform_tx_type,
        @default_limit
      )

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, transform_tx_type, @default_limit)
    end

    # Tests when direction `backward` and different `type` and `type_group` parameters
    test "get transactions when direction=backward, type=contract_call and type_group=oracle", %{
      conn: conn
    } do
      limit = 31
      type_group = "oracle"
      type = "contract_call"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "backward", "type", type, "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, transform_tx_type, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, transform_tx_type, limit)
    end

    test "get transactions when direction=backward, type=channel_close_solo and type_group=name",
         %{
           conn: conn
         } do
      limit = 18
      type_group = "name"
      type = "channel_close_solo"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "backward", "type", type, "type_group", type_group, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], txs_types_by_tx_group, transform_tx_type, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, transform_tx_type, limit)
    end

    test "get transactions when direction=backward, type=oracle_register and type_group=spend with default limit",
         %{conn: conn} do
      type_group = "spend"
      type = "oracle_register"

      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)
      transform_tx_type = transform_tx_type(type)

      conn = request_txs(conn, "backward", "type", type, "type_group", type_group)
      response = json_response(conn, 200)

      check_response_data(
        response["data"],
        txs_types_by_tx_group,
        transform_tx_type,
        @default_limit
      )

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(txs_types_by_tx_group, transform_tx_type, @default_limit)
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
    # Tests when direction `forward` and different `id` parameters
    test "get transactions when direction=forward and given account ID", %{conn: conn} do
      limit = 13
      criteria = "account"

      <<_prefix::3-binary, rest::binary>> =
        id = "ak_26ubrEL8sBqYNp4kvKb1t4Cg7XsCciYq4HdznrvfUkW359gf17"

      conn = request_txs(conn, "forward", criteria, id, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], rest, :no_prefix, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(rest, :no_prefix, limit)
    end

    test "gets account transactions with name details using forward", %{conn: conn} do
      # "recipient":{"account":"ak_2ZyuUxyfbkNbKZnGStgkCQuRwCPQWducVipxE4Ci7RU8UuTiry","name":"katie.chain"}
      # "recipient_id":"nm_2mcA6LRcH3bjJvs4qTDRGkN9hCyMj9da83gU5WKy9u1EmrExar"
      # "tx_index":7090883
      assert_recipient_for_spend_tx_with_name(
        conn,
        "forward",
        "ak_2ZyuUxyfbkNbKZnGStgkCQuRwCPQWducVipxE4Ci7RU8UuTiry",
        5
      )
    end

    test "gets account transactions and recipient details on a name with multiple updates (two before spend_tx)",
         %{conn: conn} do
      limit = 63
      criteria = "account"
      account_id = "ak_u2gFpRN5nABqfqb5Q3BkuHCf8c7ytcmqovZ6VyKwxmVNE5jqa"

      conn = request_txs(conn, "forward", criteria, account_id, limit)
      response = json_response(conn, 200)

      blocks_with_nm =
        Enum.filter(response["data"], fn %{"tx" => tx} ->
          tx["type"] == @type_spend_tx and
            String.starts_with?(tx["recipient_id"] || "", "nm_")
        end)

      assert Enum.any?(blocks_with_nm, fn %{"tx" => tx, "tx_index" => spend_txi} ->
               assert {:ok, plain_name} = Validate.plain_name(tx["recipient_id"])
               assert recipient = tx["recipient"]

               assert recipient["name"] == plain_name

               assert {:ok, recipient_account_pk} = Name.account_pointer_at(plain_name, spend_txi)
               assert recipient["account"] == Enc.encode(:account_pubkey, recipient_account_pk)

               if plain_name == "kiwicrestorchard.chain" do
                 updates_before_spend_list =
                   plain_name
                   |> Name.locate()
                   |> elem(0)
                   |> Model.name(:updates)
                   |> Enum.filter(fn {_update_height, update_txi} ->
                     update_txi < spend_txi
                   end)
                   |> Enum.map(&elem(&1, 1))

                 # assure validation of recipient account when there were 2 updates before the spend_tx
                 assert [update_txi_before_spend, first_update_txi_before_spend] =
                          updates_before_spend_list

                 assert spend_txi > update_txi_before_spend
                 assert update_txi_before_spend > first_update_txi_before_spend
                 true
               else
                 false
               end
             end)
    end

    test "get transactions with direction=forward and given contract ID with default limit", %{
      conn: conn
    } do
      criteria = "contract"

      <<_prefix::3-binary, rest::binary>> =
        id = "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"

      conn = request_txs(conn, "forward", criteria, id)
      response = json_response(conn, 200)

      check_response_data(response["data"], rest, :no_prefix, @default_limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(rest, :no_prefix, @default_limit)
    end

    test "get transactions with direction=forward and given oracle ID with default limit", %{
      conn: conn
    } do
      criteria = "oracle"

      <<_prefix::3-binary, rest::binary>> =
        id = "ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"

      conn = request_txs(conn, "forward", criteria, id)
      response = json_response(conn, 200)

      check_response_data(response["data"], rest, :no_prefix, @default_limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(rest, :no_prefix, @default_limit)
    end

    # Tests when direction `backward` and different `id` parameters
    test "get transactions when direction=backward and given account ID", %{conn: conn} do
      limit = 3
      criteria = "account"

      <<_prefix::3-binary, rest::binary>> =
        id = "ak_wTPFpksUJFjjntonTvwK4LJvDw11DPma7kZBneKbumb8yPeFq"

      conn = request_txs(conn, "backward", criteria, id, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], rest, :no_prefix, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(rest, :no_prefix, limit)
    end

    test "gets account transactions with name details using backward", %{conn: conn} do
      # "recipient":{"account":"ak_u2gFpRN5nABqfqb5Q3BkuHCf8c7ytcmqovZ6VyKwxmVNE5jqa","name":"josh.chain"}
      # "sender_id":"ak_2ZyuUxyfbkNbKZnGStgkCQuRwCPQWducVipxE4Ci7RU8UuTiry"
      # "tx_index":11896169
      assert_recipient_for_spend_tx_with_name(
        conn,
        "backward",
        "ak_2ZyuUxyfbkNbKZnGStgkCQuRwCPQWducVipxE4Ci7RU8UuTiry",
        4
      )
    end

    test "get transactions when direction=backward and given contract ID with default limit", %{
      conn: conn
    } do
      criteria = "contract"

      <<_prefix::3-binary, rest::binary>> =
        id = "ct_2rtXsV55jftV36BMeR5gtakN2VjcPtZa3PBURvzShSYWEht3Z7"

      conn = request_txs(conn, "backward", criteria, id)
      response = json_response(conn, 200)

      check_response_data(response["data"], rest, :no_prefix, @default_limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(rest, :no_prefix, @default_limit)
    end

    test "get transactions when direction=backward and given oracle ID with default limit", %{
      conn: conn
    } do
      criteria = "oracle"

      <<_prefix::3-binary, rest::binary>> =
        id = "ok_28QDg7fkF5qiKueSdUvUBtCYPJdmMEoS73CztzXCRAwMGKHKZh"

      conn = request_txs(conn, "backward", criteria, id)
      response = json_response(conn, 200)

      check_response_data(response["data"], rest, :no_prefix, @default_limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(rest, :no_prefix, @default_limit)
    end

    test "renders errors when direction=forward and invalid ID", %{conn: conn} do
      id = "some_invalid_key"
      conn = get(conn, "/txs/forward?account=#{id}")

      assert json_response(conn, 400) == %{"error" => "invalid id: #{id}"}
    end

    test "renders errors when direction=forward and the ID is valid, but not pass correctly ",
         %{conn: conn} do
      id = "ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"
      # the oracle id is valid but is passed as account id, which is not correct
      conn = get(conn, "/txs/backward?account=#{id}")

      assert json_response(conn, 400) == %{"error" => "invalid id: #{id}"}
    end
  end

  # These tests will work only for mainnet, because of the hardcoded IDs and they are valid only for mainnet network
  describe "txs_direction with transaction fields" do
    # Tests when direction is `forward`, tx_type and field parameters
    test "get transactions when direction=forward, tx_type=contract_call and field=caller_id ", %{
      conn: conn
    } do
      limit = 8
      tx_type = "contract_call"
      field = "caller_id"
      id = "ak_YCwfWaW5ER6cRsG9Jg4KMyVU59bQkt45WvcnJJctQojCqBeG2"

      conn = request_txs_by_field(conn, "forward", tx_type, field, id, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], field, id, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(field, id, limit)
    end

    test "get transactions when direction=forward, tx_type=channel_create and field=initiator_id ",
         %{conn: conn} do
      limit = 5
      tx_type = "channel_create"
      field = "initiator_id"
      id = "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS"

      conn = request_txs_by_field(conn, "forward", tx_type, field, id, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], field, id, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(field, id, limit)
    end

    test "get transactions when direction=forward, tx_type=ga_attach and field=owner_id ",
         %{conn: conn} do
      limit = 1
      tx_type = "ga_attach"
      field = "owner_id"
      id = "ak_2RUVa9bvHUD8wYSrvixRjy9LonA9L29wRvwDfQ4y37ysMKjgdQ"

      conn = request_txs_by_field(conn, "forward", tx_type, field, id, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], field, id, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]
    end

    test "get transactions when direction=forward, tx_type=spend and field=recipient_id ",
         %{conn: conn} do
      tx_type = "spend"
      field = "recipient_id"
      id = "ak_wTPFpksUJFjjntonTvwK4LJvDw11DPma7kZBneKbumb8yPeFq"

      conn = request_txs_by_field(conn, "forward", tx_type, field, id, @default_limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], field, id, @default_limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(field, id, @default_limit)
    end

    test "get transactions when direction=forward, tx_type=oracle_query and field=sender_id ",
         %{conn: conn} do
      tx_type = "oracle_query"
      field = "sender_id"
      id = "ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b"

      conn = request_txs_by_field(conn, "forward", tx_type, field, id)
      response = json_response(conn, 200)

      check_response_data(response["data"], field, id, @default_limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(field, id, @default_limit)
    end

    # Tests with direction `backward`, tx_type and field parameters
    test "get transactions when direction=backward, tx_type=channel_deposit and field=channel_id ",
         %{
           conn: conn
         } do
      limit = 1
      tx_type = "channel_deposit"
      field = "channel_id"
      id = "ch_2KKS3ypddUfYovJSeg4ues2wFdUoGH8ZtunDhrxvGkYNhzP5TC"

      conn = request_txs_by_field(conn, "forward", tx_type, field, id, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], field, id, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]
    end

    test "get transactions when direction=backward, tx_type=name_update and field=name_id ", %{
      conn: conn
    } do
      limit = 2
      tx_type = "name_update"
      field = "name_id"
      id = "nm_2ANVLWij71wHMvGyQAEb2zYk8bC7v9C8svVm8HLND6vYaChdnd"

      conn = request_txs_by_field(conn, "forward", tx_type, field, id, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], field, id, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(field, id, limit)
    end

    test "renders errors when direction=forward, tx_type=oracle_query and given transaction field is wrong ",
         %{conn: conn} do
      tx_type = "oracle_query"
      field = "account_id"
      id = "ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b"
      conn = get(conn, "/txs/forward?#{tx_type}.#{field}=#{id}")

      assert json_response(conn, 400) == %{"error" => "invalid transaction field: :#{field}"}
    end

    test "renders errors when direction=forward, tx_type and field are invalid ",
         %{conn: conn} do
      tx_type = "invalid"
      field = "account_id"
      id = "ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b"
      conn = get(conn, "/txs/forward?#{tx_type}.#{field}=#{id}")

      assert json_response(conn, 400) == %{"error" => "invalid transaction type: #{tx_type}"}
    end
  end

  describe "txs with inner transactions" do
    test "on forward and field=recipient_id ", %{conn: conn} do
      field = "recipient_id"
      id = "ak_2RUVa9bvHUD8wYSrvixRjy9LonA9L29wRvwDfQ4y37ysMKjgdQ"

      conn = request_txs_by_field(conn, "forward", field, id)
      response = json_response(conn, 200)

      assert Enum.any?(response["data"], fn %{"tx" => block_tx} ->
               if block_tx["type"] == "GAMetaTx" do
                 assert block_tx["tx"]["tx"]["recipient_id"] == id
                 true
               else
                 assert block_tx["recipient_id"] == id
                 false
               end
             end)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]
    end

    test "on backward and field=sender_id ", %{conn: conn} do
      field = "sender_id"
      id = "ak_oTX3ffD9XewhuLAquSKHBdm4jhhKb24NKsesGSWM4UKg6gWp4"

      conn = request_txs_by_field(conn, "backward", field, id)
      response = json_response(conn, 200)

      assert Enum.any?(response["data"], fn %{"tx" => block_tx} ->
               if block_tx["type"] == "GAMetaTx" do
                 assert block_tx["tx"]["tx"]["sender_id"] == id
                 true
               else
                 assert block_tx["sender_id"] == id
                 false
               end
             end)
    end

    test "on range and field=account ", %{conn: conn} do
      range = 142_398..142_415
      field = "account"
      id = "ak_2RUVa9bvHUD8wYSrvixRjy9LonA9L29wRvwDfQ4y37ysMKjgdQ"

      conn = request_txs_by_field(conn, range, field, id)
      response = json_response(conn, 200)

      Enum.each(response["data"], fn %{"block_height" => block_height} ->
        assert block_height in range
      end)

      assert Enum.any?(response["data"], fn %{"tx" => block_tx} ->
               if block_tx["type"] == "GAMetaTx" do
                 block_tx["tx"]["tx"]["recipient_id"] == id
               else
                 false
               end
             end)

      assert Enum.any?(response["data"], fn %{"tx" => block_tx} ->
               if block_tx["type"] == "GAMetaTx" do
                 block_tx["tx"]["tx"]["sender_id"] == id
               else
                 false
               end
             end)

      assert Enum.any?(response["data"], fn %{"tx" => block_tx} ->
               if block_tx["type"] == "SpendTx" do
                 assert block_tx["recipient_id"] == id or block_tx["sender_id"] == id
                 true
               else
                 false
               end
             end)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]
    end
  end

  # These tests will work only for mainnet, because of the hardcoded IDs and they are valid only for mainnet network
  describe "txs_direction with mixing of query parameters" do
    test "get transactions when direction=forward, where both accounts contains ", %{
      conn: conn
    } do
      limit = 1
      account = "account"
      id_1 = "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5"
      id_2 = "ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2"

      conn = request_txs(conn, "forward", account, id_1, account, id_2, limit)
      response = json_response(conn, 200)

      check_response_data(
        response["data"],
        id_1,
        id_2,
        :with_prefix,
        limit
      )

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(id_1, id_2, :with_prefix, limit)
    end

    test "get transactions when direction=forward between sender and recipient ", %{
      conn: conn
    } do
      limit = 1
      sender_id = "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5"
      recipient_id = "ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2"

      conn =
        request_txs(conn, "forward", "sender_id", sender_id, "recipient_id", recipient_id, limit)

      response = json_response(conn, 200)

      check_response_data(
        response["data"],
        sender_id,
        recipient_id,
        :with_prefix,
        limit
      )

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(sender_id, recipient_id, :with_prefix, limit)
    end

    test "get transactions when direction=forward which are contract related transactions for account ",
         %{
           conn: conn
         } do
      limit = 3
      type_group = "contract"
      account = "ak_YCwfWaW5ER6cRsG9Jg4KMyVU59bQkt45WvcnJJctQojCqBeG2"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      conn =
        request_txs(
          conn,
          "forward",
          "account",
          account,
          "type_group",
          type_group,
          limit
        )

      response = json_response(conn, 200)

      check_response_data(
        response["data"],
        account,
        txs_types_by_tx_group,
        :with_prefix,
        limit
      )

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(account, txs_types_by_tx_group, :with_prefix, limit)
    end

    test "get transactions when direction=backward which are oracle_register related transactions for account",
         %{
           conn: conn
         } do
      limit = 1
      type = "oracle_register"
      account = "ak_g5vQK6beY3vsTJHH7KBusesyzq9WMdEYorF8VyvZURXTjLnxT"

      conn = request_txs(conn, "forward", "account", account, "type", type, limit)
      response = json_response(conn, 200)

      check_response_data(
        response["data"],
        account,
        transform_tx_type(type),
        :with_prefix,
        limit
      )

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]
    end
  end

  describe "txs_range bounded by generation" do
    test "get transactions when scope=gen at certain height and continuation", %{conn: conn} do
      height = 273_000

      conn = request_txs(conn, "gen", height)
      response = json_response(conn, 200)

      check_response_data(response["data"], height, @default_limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          @default_limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(height, @default_limit)
    end

    test "get transactions when scope=gen at certain range and continuation", %{conn: conn} do
      height_from = 197_000
      height_to = 197_003
      limit = 50

      conn = request_txs(conn, "gen", height_from, height_to, limit)
      response = json_response(conn, 200)

      check_response_data(response["data"], height_from, height_to, limit)

      {:ok, data, _has_cont?} =
        Continuation.response_data(
          {TxController, :txs, fetch_params(conn), conn.assigns.scope, 0},
          limit
        )

      assert ^data = response["data"]

      conn
      |> get_response_from_next_page(response)
      |> check_response_data(height_from, height_to, limit)
    end

    test "renders errors when scope=gen with a valid range and random access", %{
      conn: conn
    } do
      height_from = 223_000
      height_to = 223_007
      limit = 15
      page = 6

      conn = get(conn, "/txs/gen/#{height_from}-#{height_to}?limit=#{limit}&page=#{page}")

      assert json_response(conn, 400) == %{"error" => "random access not supported"}
    end

    test "renders errors when is passed invalid scope", %{conn: conn} do
      height_from = 223_000
      height_to = 223_007

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
    test "get transactions when scope=txi and transaction index", %{conn: conn} do
      index = 605_999

      conn = get(conn, "/txs/txi/#{index}")

      response = json_response(conn, 200)["data"]

      Enum.each(response, fn data ->
        assert data["tx_index"] == index
      end)
    end

    test "get transactions when scope=txi and in a range transaction indexes", %{conn: conn} do
      index_from = 700_000
      index_to = 700_025
      limit = 25

      conn = get(conn, "/txs/txi/#{index_from}-#{index_to}?limit=#{limit}")

      response = json_response(conn, 200)["data"]

      assert Enum.count(response) == limit

      Enum.each(response, fn data ->
        assert data["tx_index"] in index_from..index_to
      end)
    end

    test "renders errors when is passed invalid index", %{conn: conn} do
      invalid_index = "invalid_index"

      conn = get(conn, "/txs/txi/#{invalid_index}")

      assert json_response(conn, 400) == %{"error" => "invalid range: #{invalid_index}"}
    end
  end

  defp transform_tx_type(type), do: type |> Validate.tx_type!() |> AeMdw.Node.tx_name()

  defp get_txs_types_by_tx_group(tx_group) do
    tx_group
    |> String.to_existing_atom()
    |> AeMdw.Node.tx_group()
    |> Enum.map(&AeMdw.Node.tx_name/1)
  end

  defp keys_to_string(map) when is_map(map) do
    for {key, val} <- map, into: %{}, do: {to_string(key), keys_to_string(val)}
  end

  defp keys_to_string(value), do: value

  defp remove_prefix(<<_prefix::3-binary, rest::binary>>), do: rest
  defp remove_prefix(_no_prefix), do: false

  defp id_exists?(tx, id, :no_prefix),
    do:
      AeMdw.Node.id_fields()
      |> Enum.any?(fn field -> remove_prefix(tx[field]) == id end)

  defp id_exists?(tx, id, :with_prefix),
    do:
      AeMdw.Node.id_fields()
      |> Enum.any?(fn field -> tx[field] == id end)

  defp request_txs(conn, "gen" = scope, criteria),
    do: get(conn, "/txs/#{scope}/#{criteria}")

  defp request_txs(conn, direction, criteria, c),
    do: get(conn, "/txs/#{direction}?#{criteria}=#{c}")

  defp request_txs(conn, "gen" = scope, criteria1, criteria2, limit),
    do: get(conn, "/txs/#{scope}/#{criteria1}-#{criteria2}?limit=#{limit}")

  defp request_txs(conn, direction, criteria, c, limit),
    do: get(conn, "/txs/#{direction}?#{criteria}=#{c}&limit=#{limit}")

  defp request_txs(conn, direction, criteria1, c1, criteria2, c2),
    do: get(conn, "/txs/#{direction}?#{criteria1}=#{c1}&#{criteria2}=#{c2}")

  defp request_txs(conn, direction, criteria1, c1, criteria2, c2, limit),
    do: get(conn, "/txs/#{direction}?#{criteria1}=#{c1}&#{criteria2}=#{c2}&limit=#{limit}")

  defp request_txs_by_field(conn, %Range{first: first, last: last}, field, c),
    do: get(conn, "/txs/gen/#{first}-#{last}?#{field}=#{c}")

  defp request_txs_by_field(conn, direction, field, c),
    do: get(conn, "/txs/#{direction}?#{field}=#{c}")

  defp request_txs_by_field(conn, direction, criteria, field, c),
    do: get(conn, "/txs/#{direction}?#{criteria}.#{field}=#{c}")

  defp request_txs_by_field(conn, direction, criteria, field, c, limit),
    do: get(conn, "/txs/#{direction}?#{criteria}.#{field}=#{c}&limit=#{limit}")

  defp check_response_data(data, criteria, limit) when is_integer(criteria) do
    assert Enum.count(data) == limit

    Enum.each(data, fn info ->
      assert info["block_height"] == criteria
    end)
  end

  defp check_response_data(data, criteria, limit) when is_binary(criteria) do
    assert Enum.count(data) == limit

    Enum.each(data, fn info ->
      assert info["tx"]["type"] == criteria
    end)
  end

  defp check_response_data(data, criteria, limit)
       when is_list(criteria) do
    assert Enum.count(data) == limit

    Enum.each(data, fn info ->
      assert info["tx"]["type"] in criteria
    end)
  end

  defp check_response_data(data, criteria1, criteria2, limit)
       when is_list(criteria1) and is_binary(criteria2) do
    assert Enum.count(data) == limit

    Enum.each(data, fn info ->
      assert info["tx"]["type"] in criteria1 || info["tx"]["type"] == criteria2
    end)
  end

  defp check_response_data(data, criteria1, criteria2, limit)
       when is_integer(criteria1) and is_integer(criteria2) do
    assert Enum.count(data) == limit

    Enum.each(data, fn info ->
      assert info["block_height"] in criteria1..criteria2
    end)
  end

  defp check_response_data(data, criteria1, criteria2, limit) when is_atom(criteria2) do
    assert Enum.count(data) == limit

    Enum.each(data, fn info ->
      assert id_exists?(info["tx"], criteria1, criteria2)
    end)
  end

  defp check_response_data(data, field, id, limit) do
    assert Enum.count(data) == limit

    Enum.each(data, fn info ->
      assert info["tx"][field] == id
    end)
  end

  defp check_response_data(data, criteria1, criteria2, criteria3, limit)
       when is_list(criteria2) and is_atom(criteria3) do
    assert Enum.count(data) == limit

    Enum.each(data, fn info ->
      assert info["tx"]["type"] in criteria2
      assert id_exists?(info["tx"], criteria1, criteria3)
    end)
  end

  defp check_response_data(data, criteria1, criteria2, criteria3, limit)
       when is_binary(criteria2) and is_atom(criteria3) do
    assert Enum.count(data) == limit

    case byte_size(criteria2) > 30 do
      true ->
        Enum.each(data, fn info ->
          assert id_exists?(info["tx"], criteria1, criteria3) &&
                   id_exists?(info["tx"], criteria2, criteria3)
        end)

      false ->
        Enum.each(data, fn info ->
          assert info["tx"]["type"] == criteria2 &&
                   id_exists?(info["tx"], criteria1, criteria3)
        end)
    end
  end

  defp check_response_data_ignore_recipient(data, criteria1, limit) do
    assert Enum.count(data) == limit

    Enum.each(data, fn info ->
      if nil == info["tx"]["recipient"] do
        assert id_exists?(info["tx"], criteria1, :with_prefix)
      end
    end)
  end

  defp get_response_from_next_page(conn, response),
    do:
      conn
      |> get(response["next"])
      |> json_response(200)
      |> Access.get("data")

  defp assert_recipient_for_spend_tx_with_name(conn, direction, account_id, limit) do
    conn = request_txs(conn, direction, "account", account_id, limit)
    response = json_response(conn, 200)

    check_response_data_ignore_recipient(response["data"], account_id, limit)

    blocks_with_nm =
      Enum.filter(response["data"], fn %{"tx" => tx} ->
        tx["type"] == @type_spend_tx and
          String.starts_with?(tx["recipient_id"] || "", "nm_")
      end)

    assert Enum.any?(blocks_with_nm, fn %{"tx" => tx, "tx_index" => tx_index} ->
             assert {:ok, plain_name} = Validate.plain_name(tx["recipient_id"])
             assert Model.name(updates: name_updates) = elem(Name.locate(plain_name), 0)

             if [] != name_updates do
               assert recipient = tx["recipient"]
               assert recipient["name"] == plain_name

               assert {:ok, recipient_account_pk} = Name.account_pointer_at(plain_name, tx_index)
               assert recipient["account"] == Enc.encode(:account_pubkey, recipient_account_pk)
               true
             else
               false
             end
           end)

    conn
    |> get_response_from_next_page(response)
    |> check_response_data_ignore_recipient(account_id, limit)
  end

  defp fetch_params(%Conn{query_string: params}),
    do: params |> WebUtil.query_groups() |> Map.drop(["limit", "page", "cursor", "expand"])
end
