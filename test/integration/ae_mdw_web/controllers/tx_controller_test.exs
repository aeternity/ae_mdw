defmodule Integration.AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag :integration

  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.State
  alias AeMdw.Db.Util
  alias AeMdw.MainnetClient
  alias :aeser_api_encoder, as: Enc
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

    test "localhost has same result as mainnet", %{conn: conn} do
      tx_hash = "th_84uc6avLpH8WFMbvnYkPWSeiiCpm9wXZUnPMm5JSrjJH4djAB"
      path = "/tx/#{tx_hash}"

      conn = get(conn, path)
      assert %{"hash" => ^tx_hash} = body = json_response(conn, 200)
      assert %{body: ^body} = MainnetClient.get!(path)
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

    test "gets spend_tx with recipient details having a name with multiple updates", %{conn: conn} do
      valid_index = 5_557_826
      conn = get(conn, "/txi/#{valid_index}")

      assert json_response(conn, 200)["tx_index"] == valid_index
      assert tx = json_response(conn, 200)["tx"]
      assert tx["type"] == "SpendTx"
      assert tx["recipient_id"] == "nm_wy3s5qnkXfq3bEETvnnt6YKaGQjfyGkncSuWQk77hdke9eYpx"

      assert tx["recipient"] == %{
               "account" => "ak_2e2VkR2yABKqAenxFXSNtgNx4Lbm9aPrD34pM9sharswp5dNAc",
               "name" => "kiwicrestorchard.chain"
             }
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
      error_msg = "not found: #{index}"

      assert %{"error" => ^error_msg} = conn |> get("/txi/#{index}") |> json_response(404)
    end

    test "localhost has same result as mainnet", %{conn: conn} do
      txi = 1_000_001
      path = "/txi/#{txi}"

      conn = get(conn, path)
      assert %{"tx_index" => ^txi} = body = json_response(conn, 200)
      assert %{body: ^body} = MainnetClient.get!(path)
    end
  end

  describe "txi for contract txs" do
    test "get a ContractCreateTx with compilation info", %{conn: conn} do
      valid_index = 1_737_468
      conn = get(conn, "/txi/#{valid_index}")

      assert json_response(conn, 200)["tx_index"] == valid_index
      assert tx = json_response(conn, 200)["tx"]
      assert tx["type"] == "ContractCreateTx"
      assert tx["compiler_version"] == "2.0.0"
      assert tx["source_hash"] == "eN05+tJcdqKtrzpqKaGf7e7wSc3ARZ/hNSgeuHcoXLk="
    end

    test "get a ContractCreateTx with init args", %{conn: conn} do
      valid_index = 26_672_277
      conn = get(conn, "/txi/#{valid_index}")

      expected_args = [
        %{
          "type" => "tuple",
          "value" => [
            "Facebook Must Die?",
            "Facebook",
            "https://downdetector.com/status/facebook/map/",
            [0]
          ]
        },
        %{
          "type" => "map",
          "value" => [
            %{"key" => 0, "val" => "yes"},
            %{"key" => 1, "val" => "no"},
            %{"key" => 2, "val" => "I don't care"},
            %{"key" => 3, "val" => "Facebook is already dead"}
          ]
        },
        %{"type" => "variant", "value" => [1, 511_843]}
      ]

      assert json_response(conn, 200)["tx_index"] == valid_index
      assert tx = json_response(conn, 200)["tx"]
      assert tx["type"] == "ContractCreateTx"
      assert tx["args"] == expected_args
      assert tx["gas_used"] && tx["gas_used"] > 0
    end

    test "get a ContractCreateTx with init logs", %{conn: conn} do
      valid_index = 27_290_810
      conn = get(conn, "/txi/#{valid_index}")

      expected_logs = [
        %{
          "address" => "ct_2Wx8XQFnTL195AbFKnuHaF9VmEJnwMBBvSd6HevN2PXdM6DgKc",
          "data" => "cb_TmV3IG9yYWNsZSBjcmVhdGVkz9SK+Q==",
          "topics" => [
            "100623342200542524309993745545480803015322198156524156815048512640607290626815",
            "90327960487985279702181835269467015518430931571603930406809739954754802244075"
          ]
        }
      ]

      assert json_response(conn, 200)["tx_index"] == valid_index
      assert tx = json_response(conn, 200)["tx"]
      assert tx["type"] == "ContractCreateTx"
      assert tx["log"] == expected_logs
      assert tx["gas_used"] && tx["gas_used"] > 0
    end
  end

  describe "count" do
    test "get count of transactions at the current height", %{conn: conn} do
      %Conn{assigns: %{state: state}} = conn = get(conn, "/v2/txs/count")

      assert json_response(conn, 200) == Util.last_txi!(state)
    end
  end

  describe "count_id" do
    test "renders errors when data is invalid", %{conn: conn} do
      invalid_id = "some_invalid_id"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/txs/count/#{invalid_id}") |> json_response(400)
    end
  end

  describe "txs_direction only with direction" do
    test "get transactions when direction=forward", %{conn: conn} do
      limit = 33

      assert %{"data" => txs, "next" => next} =
               conn |> get("/v2/txs", direction: "forward", limit: limit) |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^txis = Enum.to_list(0..(limit - 1))

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^next_txis = Enum.to_list(limit..(2 * limit - 1))
    end

    test "get transactions when direction=backward", %{conn: conn} do
      limit = 24
      state = State.new()
      last_txi = Util.last_txi!(state)

      assert %{"data" => txs, "next" => next} =
               conn |> get("/v2/txs", direction: "backward", limit: limit) |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^txis = Enum.to_list(last_txi..(last_txi - limit + 1))

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^next_txis = Enum.to_list((last_txi - limit)..(last_txi - limit * 2 + 1))
    end

    test "renders errors when direction is invalid", %{conn: conn} do
      invalid_direction = "back"
      error_msg = "invalid direction: #{invalid_direction}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/txs", direction: invalid_direction) |> json_response(400)
    end
  end

  describe "txs_direction with given type parameter" do
    # Tests with direction is `forward` and different `type` parameters
    test "get transactions when direction=forward and type parameter=channel_create", %{
      conn: conn
    } do
      limit = 4
      type = "channel_create"

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "forward", type: type, limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "ChannelCreateTx" end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "ChannelCreateTx" end)
    end

    test "get transactions when direction=forward and type parameter=spend", %{conn: conn} do
      limit = 15
      type = "spend"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "forward", type: type, limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "SpendTx" end)
    end

    test "get transactions when direction=forward and type parameter=name_claim", %{conn: conn} do
      limit = 19
      type = "name_claim"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "forward", type: type, limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "NameClaimTx" end)
    end

    test "get transactions when direction=forward and type parameter=name_preclaim with default limit",
         %{conn: conn} do
      type = "name_preclaim"

      assert %{"data" => txs} =
               conn |> get("/v2/txs", direction: "forward", type: type) |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "NamePreclaimTx" end)
    end

    # Tests when direction is `backward` and different `type` parameters
    test "get transactions when direction=backward and type parameter=spend with default limit",
         %{
           conn: conn
         } do
      type = "spend"

      assert %{"data" => txs} =
               conn |> get("/v2/txs", direction: "backward", type: type) |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis, :desc)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "SpendTx" end)
    end

    test "get transactions when direction=forward and type parameter=contract_create", %{
      conn: conn
    } do
      limit = 99
      type = "contract_create"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "forward", type: type, limit: limit)
               |> json_response(200)

      assert_contract_create_fields(hd(txs)["tx"])

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "ContractCreateTx" end)
    end

    test "get transactions when direction=backward and type parameter=contract_create", %{
      conn: conn
    } do
      limit = 19
      type = "contract_create"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "backward", type: type, limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis, :desc)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "ContractCreateTx" end)
    end

    test "get transactions when direction=backward and type parameter=ga_attach", %{
      conn: conn
    } do
      limit = 1
      type = "ga_attach"

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", type: type, limit: limit)
               |> json_response(200)

      assert ^limit = length(txs)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "GAAttachTx" end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      assert ^limit = length(next_txs)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "GAAttachTx" end)
    end

    test "get transactions when direction=backward and type parameter=oracle_query", %{conn: conn} do
      limit = 15
      type = "oracle_query"

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", type: type, limit: limit)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "OracleQueryTx" end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type == "OracleQueryTx" end)
    end

    test "renders errors when type parameter is invalid", %{conn: conn} do
      invalid_type = "some_invalid_type"
      error_msg = "invalid transaction type: #{invalid_type}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/txs", direction: "forward", type: invalid_type)
               |> json_response(400)
    end
  end

  describe "txs_direction with given type_group parameter" do
    # Tests when direction is `forward` and different `type_group` parameters
    test "get transactions when direction=forward and type_group parameter=oracle", %{conn: conn} do
      limit = 18
      type_group = "oracle"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "forward", type_group: type_group, limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)
    end

    test "get transactions when direction=forward and type_group parameter=contract", %{
      conn: conn
    } do
      limit = 45
      type_group = "contract"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "forward", type_group: type_group, limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)
    end

    test "get transactions when direction=forward and type_group parameter=ga", %{conn: conn} do
      limit = 2
      type_group = "ga"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "forward", type_group: type_group, limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)
    end

    test "get transactions when direction=forward and type_group parameter=channel", %{conn: conn} do
      limit = 22
      type_group = "channel"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "forward", type_group: type_group, limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)
    end

    # Tests when direction is `backward` and different `type_group` parameters
    test "get transactions when direction=backward and type_group parameter=channel", %{
      conn: conn
    } do
      limit = 12
      type_group = "channel"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", type_group: type_group, limit: limit)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)
    end

    test "get transactions when direction=backward and type_group parameter=oracle with default limit",
         %{conn: conn} do
      type_group = "oracle"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", type_group: type_group)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert @default_limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)
    end

    test "get transactions when direction=backward and type_group parameter=contract", %{
      conn: conn
    } do
      limit = 15
      type_group = "contract"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", type_group: type_group, limit: limit)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)
    end

    test "get transactions when direction=backward and type_group parameter=ga", %{conn: conn} do
      limit = 3
      type_group = "ga"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "backward", type_group: type_group, limit: limit)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)
    end

    test "get transactions when direction=backward and type_group parameter=name", %{conn: conn} do
      limit = 35
      type_group = "name"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", type_group: type_group, limit: limit)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)
    end

    test "get transactions when direction=backward and type_group parameter=spend", %{conn: conn} do
      limit = 33
      type_group = "spend"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", type_group: type_group, limit: limit)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} -> type in txs_types_by_tx_group end)
    end

    test "renders errors when type_group parameter is invalid", %{conn: conn} do
      invalid_type_group = "some_invalid_type_group"
      error_msg = "invalid transaction group: #{invalid_type_group}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/txs", direction: "backward", type_group: invalid_type_group)
               |> json_response(400)
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

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs",
                 direction: "backward",
                 type_group: type_group,
                 type: type,
                 limit: limit
               )
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)
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

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs",
                 direction: "backward",
                 type_group: type_group,
                 type: type,
                 limit: limit
               )
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)

      assert Enum.all?(next_txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)
    end

    test "get transactions when direction=forward, type=spend and type_group=ga", %{conn: conn} do
      type_group = "ga"
      type = "spend"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)
      transform_tx_type = transform_tx_type(type)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", type_group: type_group, type: type)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert @default_limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)

      assert Enum.all?(next_txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)
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

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs",
                 direction: "backward",
                 type_group: type_group,
                 type: type,
                 limit: limit
               )
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)

      assert Enum.all?(next_txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)
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

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs",
                 direction: "backward",
                 type_group: type_group,
                 type: type,
                 limit: limit
               )
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)

      assert Enum.all?(next_txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)
    end

    test "get transactions when direction=backward, type=oracle_register and type_group=spend with default limit",
         %{conn: conn} do
      type_group = "spend"
      type = "oracle_register"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)
      transform_tx_type = transform_tx_type(type)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", type_group: type_group, type: type)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert @default_limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)

      assert Enum.all?(next_txs, fn %{"tx" => %{"type" => type}} ->
               type in txs_types_by_tx_group or type == transform_tx_type
             end)
    end

    test "renders errors when type_group parameter is invalid", %{conn: conn} do
      invalid_type_group = "some_invalid_type_group"
      type = "spend"
      error_msg = "invalid transaction group: #{invalid_type_group}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/txs", direction: "forward", type: type, type_group: invalid_type_group)
               |> json_response(400)
    end

    test "renders errors when type parameter is invalid", %{conn: conn} do
      type_group = "channel"
      invalid_type = "some_invalid_type"
      error_msg = "invalid transaction type: #{invalid_type}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/txs", direction: "forward", type: invalid_type, type_group: type_group)
               |> json_response(400)
    end
  end

  # These tests will work only for mainnet, because of the hardcoded IDs and they are valid only for mainnet network
  describe "txs_direction with generic id parameter" do
    # Tests when direction `forward` and different `id` parameters
    test "get transactions when direction=forward and given account ID", %{conn: conn} do
      limit = 13

      <<_prefix::3-binary, rest::binary>> =
        id = "ak_26ubrEL8sBqYNp4kvKb1t4Cg7XsCciYq4HdznrvfUkW359gf17"

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "forward", account: id, limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)
    end

    test "gets account transactions with name details using forward", %{conn: conn} do
      # "recipient":{"account":"ak_2ZyuUxyfbkNbKZnGStgkCQuRwCPQWducVipxE4Ci7RU8UuTiry","name":"katie.chain"}
      # "recipient_id":"nm_2mcA6LRcH3bjJvs4qTDRGkN9hCyMj9da83gU5WKy9u1EmrExar"
      # "tx_index":7090883
      state = State.new()
      account_id = "ak_2ZyuUxyfbkNbKZnGStgkCQuRwCPQWducVipxE4Ci7RU8UuTiry"
      limit = 5

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "forward", account: account_id, limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)

      blocks_with_nm =
        Enum.filter(txs, fn %{"tx" => %{"type" => type} = tx} ->
          type == @type_spend_tx and String.starts_with?(tx["recipient_id"] || "", "nm_")
        end)

      assert Enum.any?(blocks_with_nm, fn %{"tx" => tx, "tx_index" => tx_index} ->
               assert {:ok, plain_name} = Validate.plain_name(state, tx["recipient_id"])
               assert Model.name(updates: name_updates) = elem(Name.locate(state, plain_name), 0)

               if [] != name_updates do
                 assert recipient = tx["recipient"]
                 assert recipient["name"] == plain_name

                 assert {:ok, recipient_account_pk} =
                          Name.account_pointer_at(state, plain_name, tx_index)

                 assert recipient["account"] == Enc.encode(:account_pubkey, recipient_account_pk)
                 true
               else
                 false
               end
             end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
    end

    test "gets account transactions and recipient details on a name with multiple updates (two before spend_tx)",
         %{conn: conn} do
      limit = 63
      account_id = "ak_u2gFpRN5nABqfqb5Q3BkuHCf8c7ytcmqovZ6VyKwxmVNE5jqa"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "forward", account: account_id, limit: limit)
               |> json_response(200)

      assert ^limit = length(txs)
      assert_recipient_for_spend_tx_with_name(txs, account_id)
    end

    test "get transactions with direction=forward and given contract ID with default limit", %{
      conn: conn
    } do
      <<_prefix::3-binary, rest::binary>> =
        contract_id = "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "forward", contract: contract_id)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)
    end

    test "get transactions with direction=forward and given GA contract ID with default limit", %{
      conn: conn
    } do
      # Generalized Account contract_id
      limit = 1
      contract_id = "ct_Be5LcGEN2SgZh2kSvf3LqZuawN94kn77iNy5off5UfgzbiNv4"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "forward", contract: contract_id, limit: limit)
               |> json_response(200)

      assert ^limit = length(txs)

      assert Enum.all?(txs, fn %{"tx" => %{"contract_id" => c_id, "type" => type}} ->
               type == "GAAttachTx" and contract_id == c_id
             end)
    end

    test "get transactions with direction=forward and given oracle ID with default limit", %{
      conn: conn
    } do
      <<_prefix::3-binary, rest::binary>> =
        oracle_id = "ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "forward", oracle: oracle_id)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)
    end

    # Tests when direction `backward` and different `id` parameters
    test "get transactions when direction=backward and given account ID", %{conn: conn} do
      limit = 3

      <<_prefix::3-binary, rest::binary>> =
        account_id = "ak_wTPFpksUJFjjntonTvwK4LJvDw11DPma7kZBneKbumb8yPeFq"

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", account: account_id, limit: limit)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)
    end

    test "gets account transactions with name details using backward", %{conn: conn} do
      # "recipient":{"account":"ak_u2gFpRN5nABqfqb5Q3BkuHCf8c7ytcmqovZ6VyKwxmVNE5jqa","name":"josh.chain"}
      # "sender_id":"ak_2ZyuUxyfbkNbKZnGStgkCQuRwCPQWducVipxE4Ci7RU8UuTiry"
      # "tx_index":11896169
      account_id = "ak_2ZyuUxyfbkNbKZnGStgkCQuRwCPQWducVipxE4Ci7RU8UuTiry"
      limit = 4

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "backward", account: account_id, limit: limit)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert_recipient_for_spend_tx_with_name(txs, account_id)
    end

    test "get transactions when direction=backward and given contract ID with default limit", %{
      conn: conn
    } do
      <<_prefix::3-binary, rest::binary>> =
        contract_id = "ct_2rtXsV55jftV36BMeR5gtakN2VjcPtZa3PBURvzShSYWEht3Z7"

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", contract: contract_id)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert @default_limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)
    end

    test "get transactions when direction=backward and given oracle ID with default limit", %{
      conn: conn
    } do
      <<_prefix::3-binary, rest::binary>> =
        oracle_id = "ok_28QDg7fkF5qiKueSdUvUBtCYPJdmMEoS73CztzXCRAwMGKHKZh"

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", direction: "backward", oracle: oracle_id)
               |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert @default_limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> id_exists?(tx, rest, :no_prefix) end)
    end

    test "renders errors when direction=forward and invalid ID", %{conn: conn} do
      id = "some_invalid_key"
      error_msg = "invalid id: #{id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/txs", direction: "forward", account: id) |> json_response(400)
    end

    test "renders errors when direction=forward and the ID is valid, but not pass correctly ",
         %{conn: conn} do
      id = "ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"
      # the oracle id is valid but is passed as account id, which is not correct
      error_msg = "invalid id: #{id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/txs", direction: "backward", account: id) |> json_response(400)
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
      account_id = "ak_YCwfWaW5ER6cRsG9Jg4KMyVU59bQkt45WvcnJJctQojCqBeG2"
      params = [{"#{tx_type}.#{field}", account_id}, {:limit, limit}, {:direction, "forward"}]

      assert %{"data" => txs, "next" => next} =
               conn |> get("/v2/txs", params) |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> tx[field] == account_id end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> tx[field] == account_id end)
    end

    test "get transactions when direction=forward, tx_type=channel_create and field=initiator_id ",
         %{conn: conn} do
      limit = 5
      tx_type = "channel_create"
      field = "initiator_id"
      account_id = "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS"
      params = [{"#{tx_type}.#{field}", account_id}, {:limit, limit}, {:direction, "forward"}]

      assert %{"data" => txs, "next" => next} =
               conn |> get("/v2/txs", params) |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> tx[field] == account_id end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> tx[field] == account_id end)
    end

    test "get transactions when direction=forward, tx_type=ga_attach and field=owner_id ",
         %{conn: conn} do
      limit = 1
      tx_type = "ga_attach"
      field = "owner_id"
      account_id = "ak_2RUVa9bvHUD8wYSrvixRjy9LonA9L29wRvwDfQ4y37ysMKjgdQ"
      params = [{"#{tx_type}.#{field}", account_id}, {:limit, limit}, {:direction, "forward"}]

      assert %{"data" => txs} = conn |> get("/v2/txs", params) |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> tx[field] == account_id end)
    end

    test "get transactions when direction=forward, tx_type=ga_attach and field=contract_id ",
         %{conn: conn} do
      limit = 1
      tx_type = "ga_attach"
      field = "contract_id"
      contract_id = "ct_Be5LcGEN2SgZh2kSvf3LqZuawN94kn77iNy5off5UfgzbiNv4"
      params = [{"#{tx_type}.#{field}", contract_id}, {:limit, limit}, {:direction, "forward"}]

      assert %{"data" => txs} = conn |> get("/v2/txs", params) |> json_response(200)

      assert ^limit = length(txs)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type} = tx} ->
               tx[field] == contract_id and type == "GAAttachTx"
             end)
    end

    test "get transactions when direction=forward, tx_type=spend and field=recipient_id ",
         %{conn: conn} do
      tx_type = "spend"
      field = "recipient_id"
      account_id = "ak_wTPFpksUJFjjntonTvwK4LJvDw11DPma7kZBneKbumb8yPeFq"
      params = [{"#{tx_type}.#{field}", account_id}, {:direction, "forward"}]

      assert %{"data" => txs, "next" => next} =
               conn |> get("/v2/txs", params) |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> tx[field] == account_id end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> tx[field] == account_id end)
    end

    test "get transactions when sender_id = recipient_id",
         %{conn: conn} do
      id = "ak_gvxNbZf5CuxYVfcUFoKAP4geZatWaC2Yy4jpx5vZoCKank4Gc"
      hash = "th_3rw5nk53rEQzZr8xrQ6sqt2Y9Cv4U8piqiHK1KVkXCaVFMTCq"

      params = [{:scope, "gen:421792-0"}, {"spend.recipient_id", id}]

      %{"data" => txs1} = conn |> get("/v2/txs", params) |> json_response(200)

      params2 = [{:scope, "gen:421792-0"}, {"spend.sender_id", id}]

      %{"data" => txs2} = conn |> get("/v2/txs", params2) |> json_response(200)

      assert [%{"tx" => %{"sender_id" => ^id, "recipient_id" => ^id}}] =
               Enum.filter(txs1, fn tx -> tx["hash"] == hash end)

      assert [%{"tx" => %{"sender_id" => ^id, "recipient_id" => ^id}}] =
               Enum.filter(txs2, fn tx -> tx["hash"] == hash end)
    end

    test "get transactions when direction=forward, tx_type=oracle_query and field=sender_id ",
         %{conn: conn} do
      tx_type = "oracle_query"
      field = "sender_id"
      account_id = "ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b"
      params = [{"#{tx_type}.#{field}", account_id}, {:direction, "forward"}]

      assert %{"data" => txs, "next" => next} =
               conn |> get("/v2/txs", params) |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> tx[field] == account_id end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> tx[field] == account_id end)
    end

    # Tests with direction `backward`, tx_type and field parameters
    test "get transactions when direction=backward, tx_type=channel_deposit and field=channel_id ",
         %{
           conn: conn
         } do
      limit = 1
      tx_type = "channel_deposit"
      field = "channel_id"
      channel_id = "ch_2KKS3ypddUfYovJSeg4ues2wFdUoGH8ZtunDhrxvGkYNhzP5TC"
      params = [{"#{tx_type}.#{field}", channel_id}, {:limit, limit}, {:direction, "backward"}]

      assert %{"data" => txs} = conn |> get("/v2/txs", params) |> json_response(200)

      assert ^limit = length(txs)
      assert Enum.all?(txs, fn %{"tx" => tx} -> tx[field] == channel_id end)
    end

    test "get transactions when direction=backward, tx_type=name_update and field=name_id ", %{
      conn: conn
    } do
      limit = 2
      tx_type = "name_update"
      field = "name_id"
      name_id = "nm_2ANVLWij71wHMvGyQAEb2zYk8bC7v9C8svVm8HLND6vYaChdnd"
      params = [{"#{tx_type}.#{field}", name_id}, {:limit, limit}, {:direction, "backward"}]

      assert %{"data" => txs, "next" => next} =
               conn |> get("/v2/txs", params) |> json_response(200)

      txis = txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"tx" => tx} -> tx[field] == name_id end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis =
        next_txs |> Enum.map(fn %{"tx_index" => tx_index} -> tx_index end) |> Enum.reverse()

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)
      assert Enum.all?(next_txs, fn %{"tx" => tx} -> tx[field] == name_id end)
    end

    test "renders errors when direction=forward, tx_type=oracle_query and given transaction field is wrong ",
         %{conn: conn} do
      tx_type = "oracle_query"
      field = "account_id"
      id = "ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b"
      params = [{"#{tx_type}.#{field}", id}, {:direction, "forward"}]
      error_msg = "invalid transaction field: :#{field}"

      assert %{"error" => ^error_msg} = conn |> get("/v2/txs", params) |> json_response(400)
    end

    test "renders errors when direction=forward, tx_type and field are invalid ",
         %{conn: conn} do
      tx_type = "invalid"
      field = "account_id"
      id = "ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b"
      params = [{"#{tx_type}.#{field}", id}, {:direction, "forward"}]
      error_msg = "invalid transaction type: #{tx_type}"

      assert %{"error" => ^error_msg} = conn |> get("/v2/txs", params) |> json_response(400)
    end
  end

  describe "txs with inner transactions" do
    test "on forward and field=recipient_id ", %{conn: conn} do
      account_id = "ak_2RUVa9bvHUD8wYSrvixRjy9LonA9L29wRvwDfQ4y37ysMKjgdQ"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "forward", recipient_id: account_id)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^txis = Enum.sort(txis)

      assert Enum.any?(txs, fn %{"tx" => block_tx} ->
               if block_tx["type"] == "GAMetaTx" do
                 assert block_tx["tx"]["tx"]["recipient_id"] == account_id
                 true
               else
                 assert block_tx["recipient_id"] == account_id
                 false
               end
             end)
    end

    test "on backward and field=sender_id ", %{conn: conn} do
      account_id = "ak_oTX3ffD9XewhuLAquSKHBdm4jhhKb24NKsesGSWM4UKg6gWp4"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "backward", sender_id: account_id)
               |> json_response(200)

      assert Enum.any?(txs, fn %{"tx" => block_tx} ->
               if block_tx["type"] == "GAMetaTx" do
                 assert block_tx["tx"]["tx"]["sender_id"] == account_id
                 true
               else
                 assert block_tx["sender_id"] == account_id
                 false
               end
             end)
    end

    test "on range and field=account ", %{conn: conn} do
      first = 142_398
      last = 142_415
      account_id = "ak_2RUVa9bvHUD8wYSrvixRjy9LonA9L29wRvwDfQ4y37ysMKjgdQ"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", scope: "gen:#{first}-#{last}", account: account_id)
               |> json_response(200)

      assert Enum.all?(txs, fn %{"block_height" => block_height} ->
               block_height >= first and block_height <= last
             end)

      assert Enum.any?(txs, fn %{"tx" => block_tx} ->
               block_tx["type"] == "GAMetaTx" and
                 block_tx["tx"]["tx"]["recipient_id"] == account_id
             end)

      assert Enum.any?(txs, fn %{"tx" => block_tx} ->
               block_tx["type"] == "GAMetaTx" and block_tx["tx"]["tx"]["sender_id"] == account_id
             end)

      assert Enum.any?(txs, fn %{"tx" => block_tx} ->
               assert block_tx["recipient_id"] == account_id or
                        block_tx["sender_id"] == account_id

               block_tx["type"] == "SpendTx"
             end)
    end
  end

  # These tests will work only for mainnet, because of the hardcoded IDs and they are valid only for mainnet network
  describe "txs_direction with mixing of query parameters" do
    test "get transactions when direction=forward, where both accounts contains ", %{
      conn: conn
    } do
      limit = 1
      id_1 = "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5"
      id_2 = "ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", direction: "forward", account: id_1, account: id_2, limit: limit)
               |> json_response(200)

      assert ^limit = length(txs)

      assert Enum.all?(txs, fn %{"tx" => tx} ->
               id_exists?(tx, id_1, :with_prefix) and id_exists?(tx, id_2, :with_prefix)
             end)
    end

    test "get transactions when direction=forward between sender and recipient ", %{
      conn: conn
    } do
      limit = 1
      sender_id = "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5"
      recipient_id = "ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2"

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs",
                 direction: "forward",
                 sender_id: sender_id,
                 recipient_id: recipient_id,
                 limit: limit
               )
               |> json_response(200)

      assert ^limit = length(txs)

      assert Enum.all?(txs, fn %{"tx" => tx} ->
               tx["sender_id"] == sender_id and tx["recipient_id"] == recipient_id
             end)
    end

    test "get transactions when direction=forward which are contract related transactions for account ",
         %{
           conn: conn
         } do
      limit = 3
      type_group = "contract"
      account_id = "ak_YCwfWaW5ER6cRsG9Jg4KMyVU59bQkt45WvcnJJctQojCqBeG2"
      txs_types_by_tx_group = get_txs_types_by_tx_group(type_group)

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs",
                 direction: "forward",
                 account: account_id,
                 type_group: type_group,
                 limit: limit
               )
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type} = tx} ->
               type in txs_types_by_tx_group and id_exists?(tx, account_id, :with_prefix)
             end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type} = tx} ->
               type in txs_types_by_tx_group and id_exists?(tx, account_id, :with_prefix)
             end)
    end

    test "get transactions when direction=backward which are oracle_register related transactions for account",
         %{
           conn: conn
         } do
      limit = 1
      type = "oracle_register"
      account_id = "ak_g5vQK6beY3vsTJHH7KBusesyzq9WMdEYorF8VyvZURXTjLnxT"
      transform_tx_type = transform_tx_type(type)

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs",
                 direction: "backward",
                 account: account_id,
                 type: type,
                 limit: limit
               )
               |> json_response(200)

      assert ^limit = length(txs)

      assert Enum.all?(txs, fn %{"tx" => %{"type" => type} = tx} ->
               type == transform_tx_type and id_exists?(tx, account_id, :with_prefix)
             end)
    end
  end

  describe "txs_range bounded by generation" do
    test "get transactions when scope=gen at certain height and continuation", %{conn: conn} do
      height = 273_000

      assert %{"data" => txs, "next" => next} =
               conn |> get("/v2/txs", scope: "gen:#{height}-#{height}") |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(txs)
      assert ^txis = Enum.sort(txis)
      assert Enum.all?(txs, fn %{"block_height" => block_height} -> block_height == height end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert @default_limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)

      assert Enum.all?(next_txs, fn %{"block_height" => block_height} ->
               block_height == height
             end)
    end

    test "get transactions when scope=gen at certain range and continuation", %{conn: conn} do
      height_from = 197_000
      height_to = 197_003
      limit = 50

      assert %{"data" => txs, "next" => next} =
               conn
               |> get("/v2/txs", scope: "gen:#{height_from}-#{height_to}", limit: limit)
               |> json_response(200)

      txis = Enum.map(txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(txs)
      assert ^txis = Enum.sort(txis)

      assert Enum.all?(txs, fn %{"block_height" => block_height} ->
               height_from <= block_height and block_height <= height_to
             end)

      assert %{"data" => next_txs} = conn |> get(next) |> json_response(200)

      next_txis = Enum.map(next_txs, fn %{"tx_index" => tx_index} -> tx_index end)

      assert ^limit = length(next_txs)
      assert ^next_txis = Enum.sort(next_txis)

      assert Enum.all?(next_txs, fn %{"block_height" => block_height} ->
               height_from <= block_height and block_height <= height_to
             end)
    end

    test "renders errors when is passed invalid scope", %{conn: conn} do
      height_from = 223_000
      height_to = 223_007
      error_msg = "invalid scope: invalid_scope"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/txs", scope: "invalid_scope:#{height_from}-#{height_to}")
               |> json_response(400)
    end

    test "renders errors when is passed invalid range", %{conn: conn} do
      invalid_range = "invalid_range"
      error_msg = "invalid range: #{invalid_range}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/txs", scope: "gen:#{invalid_range}") |> json_response(400)
    end
  end

  describe "txs_range bounded by transaction index" do
    test "get transactions when scope=txi and transaction index", %{conn: conn} do
      index = 605_999

      assert %{"data" => txs} =
               conn |> get("/v2/txs", scope: "txi:#{index}") |> json_response(200)

      assert Enum.all?(txs, fn %{"tx_index" => tx_index} -> tx_index == index end)
    end

    test "get transactions when scope=txi and in a range transaction indexes", %{conn: conn} do
      index_from = 700_000
      index_to = 700_025
      limit = 25

      assert %{"data" => txs} =
               conn
               |> get("/v2/txs", scope: "txi:#{index_from}-#{index_to}", limit: limit)
               |> json_response(200)

      assert ^limit = length(txs)
      assert Enum.all?(txs, fn %{"tx_index" => tx_index} -> tx_index in index_from..index_to end)
    end

    test "renders errors when is passed invalid index", %{conn: conn} do
      invalid_index = "invalid_index"
      error_msg = "invalid scope: #{invalid_index}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/txs", scope: invalid_index) |> json_response(400)
    end
  end

  describe "micro_blocks_txs" do
    test "it gets paginated txs from a given micro-block", %{conn: conn} do
      mb_hash = "mh_2jegeDKb3JyRdgoEyXmJSbwcsZVgKzfFUMtsuPmv1TT3Mbnv71"

      assert %{"data" => [tx1, tx2]} =
               conn
               |> get("/v2/micro-blocks/#{mb_hash}/txs")
               |> json_response(200)

      assert %{"block_hash" => ^mb_hash, "tx_index" => 9_351_444} = tx1
      assert %{"block_hash" => ^mb_hash, "tx_index" => 9_351_443} = tx2
    end
  end

  defp transform_tx_type(type), do: type |> Validate.tx_type!() |> AeMdw.Node.tx_name()

  defp get_txs_types_by_tx_group(tx_group) do
    tx_group
    |> String.to_existing_atom()
    |> AeMdw.Node.tx_group()
    |> Enum.map(&AeMdw.Node.tx_name/1)
  end

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

  defp assert_recipient_for_spend_tx_with_name(txs, account_id) do
    state = State.new()

    Enum.each(txs, fn %{"tx" => tx} ->
      if nil == tx["recipient"] do
        assert id_exists?(tx, account_id, :with_prefix)
      end
    end)

    blocks_with_nm =
      Enum.filter(txs, fn %{"tx" => tx} ->
        tx["type"] == @type_spend_tx and
          String.starts_with?(tx["recipient_id"] || "", "nm_")
      end)

    assert Enum.any?(blocks_with_nm, fn %{"tx" => tx, "tx_index" => tx_index} ->
             assert {:ok, plain_name} = Validate.plain_name(state, tx["recipient_id"])
             assert Model.name(updates: name_updates) = elem(Name.locate(state, plain_name), 0)

             if [] != name_updates do
               assert recipient = tx["recipient"]
               assert recipient["name"] == plain_name

               assert {:ok, recipient_account_pk} =
                        Name.account_pointer_at(state, plain_name, tx_index)

               assert recipient["account"] == Enc.encode(:account_pubkey, recipient_account_pk)
               true
             else
               false
             end
           end)
  end

  defp assert_contract_create_fields(tx) do
    assert tx["compiler_version"] == nil
    assert tx["source_hash"] == "P9ddDnECNFDZtun/Kvi5cOcQRqSHHZPubbCyqVqphpA="
    assert tx["abi_version"] == 1
    assert tx["amount"] == 1
    assert tx["args"] == %{"type" => "tuple", "value" => []}

    assert tx["call_data"] ==
             "cb_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACC5yVbyizFJqfWYeqUF89obIgnMVzkjQAYrtsG9n5+Z6gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAnHQYrA=="

    assert tx["caller_id"] == "ak_ZLqPe9J2qenismR9FoJ93zJs8To91LQH9iVb2X4HRkRKMpxXt"

    assert tx["code"] ==
             "cb_+QPvRgGgP9ddDnECNFDZtun/Kvi5cOcQRqSHHZPubbCyqVqphpD5Avv5ASqgaPJnYzj/UIg5q6R3Se/6i+h+8oTyB/s9mZhwHNU4h8WEbWFpbrjAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKD//////////////////////////////////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+QHLoLnJVvKLMUmp9Zh6pQXz2hsiCcxXOSNABiu2wb2fn5nqhGluaXS4YAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP//////////////////////////////////////////7kBQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEA//////////////////////////////////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA///////////////////////////////////////////uMxiAABkYgAAhJGAgIBRf7nJVvKLMUmp9Zh6pQXz2hsiCcxXOSNABiu2wb2fn5nqFGIAAMBXUIBRf2jyZ2M4/1CIOaukd0nv+ovofvKE8gf7PZmYcBzVOIfFFGIAAK9XUGABGVEAW2AAGVlgIAGQgVJgIJADYAOBUpBZYABRWVJgAFJgAPNbYACAUmAA81tZWWAgAZCBUmAgkANgABlZYCABkIFSYCCQA2ADgVKBUpBWW2AgAVFRWVCAkVBQgJBQkFZbUFCCkVBQYgAAjFax6Hle"

    assert tx["contract_id"] == "ct_2ostji4QgnbaVCqAyzVhKor8dSZUYVv5MRRB2KsJVxAt4UC33J"
    assert tx["deposit"] == 4
    assert tx["fee"] == 1_655_760
    assert tx["gas"] == 1_579_000
    assert tx["gas_price"] == 1
    assert tx["gas_used"] == 193
    assert tx["log"] == []
    assert tx["nonce"] == 1
    assert tx["owner_id"] == "ak_ZLqPe9J2qenismR9FoJ93zJs8To91LQH9iVb2X4HRkRKMpxXt"
    assert tx["return_type"] == "ok"
    assert tx["return_value"] == "cb_Xfbg4g=="
    assert tx["ttl"] == 4543
    assert tx["type"] == "ContractCreateTx"
    assert tx["version"] == 1
    assert tx["vm_version"] == 1
  end
end
