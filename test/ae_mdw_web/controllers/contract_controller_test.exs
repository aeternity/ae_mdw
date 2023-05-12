defmodule AeMdwWeb.Controllers.ContractControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  import Mock

  require Model

  @default_limit 10

  @evt1_ctor_name "Transfer"
  @evt1_hash :aec_hash.blake2b_256_hash(@evt1_ctor_name)
  @evt2_ctor_name "evt2_name"
  @evt2_hash :aec_hash.blake2b_256_hash(@evt2_ctor_name)
  @event_hashes [Base.hex_encode32(@evt1_hash), Base.hex_encode32(@evt2_hash)]

  @aex9_events ["Burn", "Mint", "Swap", "Transfer"]
  @aex141_events [
    "Burn",
    "Mint",
    "TemplateCreation",
    "TemplateDeletion",
    "TemplateMint",
    "TemplateLimit",
    "TemplateLimitDecrease",
    "TokenLimit",
    "TokenLimitDecrease",
    "Transfer"
  ]

  @log_kbi 101
  @log_mbi 1
  @log_block_hash :crypto.strong_rand_bytes(32)
  @first_log_txi 1_000_001
  @evt1_amount 20
  @mixed_logs_amount 40
  @contract_logs_amount 20
  @last_log_txi @first_log_txi + @mixed_logs_amount + @contract_logs_amount + length(@aex9_events) +
                  length(@aex141_events)
  @log_txis @first_log_txi..@last_log_txi

  @call_kbi 201
  @call_mbi 1
  @call_block_hash :crypto.strong_rand_bytes(32)
  @first_call_txi 2_000_001
  @mixed_calls_amount 30
  @contract_calls_amount 40
  @last_call_txi @first_call_txi + div(@mixed_calls_amount, 2) + div(@contract_calls_amount, 2)
  @call_txis @first_call_txi..@last_call_txi
  @call_function "Chain.spend"
  @sender_pk <<1::256>>

  setup_all _context do
    contract_pk = :crypto.strong_rand_bytes(32)
    aex9_contract_pk = :crypto.strong_rand_bytes(32)
    aex141_contract_pk = :crypto.strong_rand_bytes(32)

    store =
      NullStore.new()
      |> MemStore.new()
      |> logs_setup(contract_pk, aex9_contract_pk, aex141_contract_pk)
      |> calls_setup(contract_pk)

    [
      store: store,
      contract_pk: contract_pk,
      aex9_contract_pk: aex9_contract_pk,
      aex141_contract_pk: aex141_contract_pk
    ]
  end

  describe "fetch_logs/5" do
    test "renders all saved contract logs with limit=100", %{
      conn: conn,
      store: store,
      contract_pk: contract_pk,
      aex9_contract_pk: aex9_contract_pk,
      aex141_contract_pk: aex141_contract_pk
    } do
      assert %{"data" => logs, "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/logs?limit=100&aexn-args=true")
               |> json_response(200)

      assert @mixed_logs_amount + @contract_logs_amount + length(@aex9_events) +
               length(@aex141_events) + 1 == length(logs)

      state = State.new(store)

      contracts_txi = [
        Origin.tx_index!(state, {:contract, contract_pk}),
        Origin.tx_index!(state, {:contract, aex9_contract_pk}),
        Origin.tx_index!(state, {:contract, aex141_contract_pk})
      ]

      Enum.each(logs, fn %{
                           "contract_txi" => create_txi,
                           "contract_tx_hash" => contract_tx_hash,
                           "contract_id" => contract_id,
                           "ext_caller_contract_txi" => create_txi,
                           "ext_caller_contract_tx_hash" => contract_tx_hash,
                           "ext_caller_contract_id" => contract_id,
                           "parent_contract_id" => nil,
                           "call_txi" => call_txi,
                           "call_tx_hash" => call_tx_hash,
                           "args" => args,
                           "data" => data,
                           "event_hash" => event_hash,
                           "event_name" => event_name,
                           "height" => height,
                           "micro_index" => micro_index,
                           "block_hash" => block_hash,
                           "log_idx" => log_idx
                         } ->
        assert create_txi == call_txi - 100 or create_txi in contracts_txi
        assert contract_tx_hash == encode(:tx_hash, Txs.txi_to_hash(state, create_txi))
        assert contract_id == encode_contract(Origin.pubkey(state, {:contract, create_txi}))
        assert call_tx_hash == encode(:tx_hash, Txs.txi_to_hash(state, call_txi))

        if event_name == "Burn" do
          [account, value] = args
          assert String.starts_with?(account, "ak") and value == call_txi
        else
          assert args == [to_string(call_txi)]
        end

        assert data == "0x" <> Integer.to_string(call_txi, 16)

        assert event_hash in @event_hashes or event_name in @aex9_events or
                 event_name in @aex141_events

        assert height == @log_kbi
        assert micro_index == @log_mbi
        assert block_hash == encode(:micro_block_hash, @log_block_hash)
        assert log_idx == rem(call_txi, 5)
      end)
    end

    test "returns paginated contract logs by desc call txi", %{conn: conn, store: store} do
      assert %{"data" => logs, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/logs")
               |> json_response(200)

      assert @default_limit = length(logs)
      assert ^logs = Enum.sort_by(logs, & &1["call_txi"], :desc)
      assert hd(logs)["call_txi"] == @last_log_txi

      Enum.each(logs, fn %{
                           "call_txi" => call_txi,
                           "height" => height,
                           "micro_index" => micro_index,
                           "block_hash" => block_hash
                         } ->
        assert call_txi in @log_txis
        assert height == @log_kbi
        assert micro_index == @log_mbi
        assert block_hash == encode(:micro_block_hash, @log_block_hash)
      end)

      assert %{"data" => next_logs, "prev" => prev_logs} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_logs)
      assert ^next_logs = Enum.sort_by(next_logs, & &1["call_txi"], :desc)
      assert hd(next_logs)["call_txi"] == @last_log_txi - 10

      assert Enum.all?(next_logs, fn %{
                                       "call_txi" => call_txi,
                                       "height" => height,
                                       "micro_index" => micro_index,
                                       "block_hash" => block_hash
                                     } ->
               call_txi in @log_txis and height == @log_kbi and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => ^logs} =
               conn |> with_store(store) |> get(prev_logs) |> json_response(200)
    end

    test "returns paginated contract logs by asc call txi", %{conn: conn, store: store} do
      assert %{"data" => logs, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/logs", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(logs)
      assert ^logs = Enum.sort_by(logs, & &1["call_txi"])
      assert hd(logs)["call_txi"] == @first_log_txi

      assert Enum.all?(logs, fn %{
                                  "call_txi" => call_txi,
                                  "height" => height,
                                  "micro_index" => micro_index,
                                  "block_hash" => block_hash
                                } ->
               call_txi in @log_txis and height == @log_kbi and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => next_logs, "prev" => prev_logs} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_logs)
      assert ^next_logs = Enum.sort_by(next_logs, & &1["call_txi"])
      assert hd(next_logs)["call_txi"] == @first_log_txi + 10

      assert Enum.all?(next_logs, fn %{
                                       "call_txi" => call_txi,
                                       "height" => height,
                                       "micro_index" => micro_index,
                                       "block_hash" => block_hash
                                     } ->
               call_txi in @log_txis and height == @log_kbi and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => ^logs} =
               conn |> with_store(store) |> get(prev_logs) |> json_response(200)
    end

    test "returns contract logs filtered by contract", %{
      conn: conn,
      store: store,
      contract_pk: contract_pk
    } do
      contract_id = encode_contract(contract_pk)

      assert %{"data" => logs, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/logs", contract: contract_id, direction: :forward)
               |> json_response(200)

      assert @default_limit = length(logs)
      assert ^logs = Enum.sort_by(logs, & &1["call_txi"])
      assert hd(logs)["call_txi"] == @first_log_txi + @mixed_logs_amount

      assert Enum.all?(logs, fn %{
                                  "contract_id" => ct_id,
                                  "call_txi" => call_txi,
                                  "height" => height,
                                  "micro_index" => micro_index,
                                  "block_hash" => block_hash
                                } ->
               ct_id == contract_id and call_txi in @log_txis and height == @log_kbi and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => next_logs, "prev" => prev_logs} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_logs)
      assert ^next_logs = Enum.sort_by(next_logs, & &1["call_txi"])
      assert hd(next_logs)["call_txi"] == @first_log_txi + @mixed_logs_amount + 10

      assert Enum.all?(next_logs, fn %{
                                       "contract_id" => ct_id,
                                       "call_txi" => call_txi,
                                       "height" => height,
                                       "micro_index" => micro_index,
                                       "block_hash" => block_hash
                                     } ->
               ct_id == contract_id and call_txi in @log_txis and height == @log_kbi and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => ^logs} =
               conn |> with_store(store) |> get(prev_logs) |> json_response(200)
    end

    test "returns logs with event names for AEX-9 events", %{
      conn: conn,
      store: store,
      aex9_contract_pk: contract_pk
    } do
      contract_id = encode_contract(contract_pk)

      assert %{"data" => logs} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/logs", contract: contract_id, direction: :forward)
               |> json_response(200)

      assert length(logs) == length(@aex9_events)

      assert Enum.all?(logs, fn %{
                                  "contract_id" => ct_id,
                                  "height" => height,
                                  "micro_index" => micro_index,
                                  "block_hash" => block_hash,
                                  "event_hash" => event_hash,
                                  "event_name" => event_name
                                } ->
               ct_id == contract_id and height == @log_kbi and micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash) and
                 event_hash == Base.hex_encode32(:aec_hash.blake2b_256_hash(event_name)) and
                 event_name in @aex9_events
             end)
    end

    test "returns logs with event names for AEX-141 events", %{
      conn: conn,
      store: store,
      aex141_contract_pk: contract_pk
    } do
      contract_id = encode_contract(contract_pk)

      assert %{"data" => logs} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/logs", contract: contract_id, direction: :forward)
               |> json_response(200)

      assert length(logs) == length(@aex141_events)

      assert Enum.all?(logs, fn %{
                                  "contract_id" => ct_id,
                                  "height" => height,
                                  "micro_index" => micro_index,
                                  "block_hash" => block_hash,
                                  "event_hash" => event_hash,
                                  "event_name" => event_name
                                } ->
               ct_id == contract_id and height == @log_kbi and micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash) and
                 event_hash == Base.hex_encode32(:aec_hash.blake2b_256_hash(event_name)) and
                 event_name in @aex141_events
             end)
    end

    test "returns contract logs filtered by data", %{
      conn: conn,
      store: store
    } do
      data_prefix = "0x#{Integer.to_string(@first_log_txi, 16)}" |> String.slice(0, 5)

      assert %{"data" => logs, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/logs", data: data_prefix, direction: :forward)
               |> json_response(200)

      assert @default_limit = length(logs)
      assert ^logs = Enum.sort_by(logs, & &1["call_txi"])
      assert hd(logs)["call_txi"] == @first_log_txi

      assert Enum.all?(logs, fn %{
                                  "data" => data,
                                  "call_txi" => call_txi,
                                  "height" => height,
                                  "micro_index" => micro_index,
                                  "block_hash" => block_hash
                                } ->
               String.starts_with?(data, data_prefix) and call_txi in @log_txis and
                 height == @log_kbi and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => next_logs, "prev" => prev_logs} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_logs)
      assert ^next_logs = Enum.sort_by(next_logs, & &1["call_txi"])
      assert hd(next_logs)["call_txi"] == @first_log_txi + 10

      assert Enum.all?(next_logs, fn %{
                                       "data" => data,
                                       "call_txi" => call_txi,
                                       "height" => height,
                                       "micro_index" => micro_index,
                                       "block_hash" => block_hash
                                     } ->
               String.starts_with?(data, data_prefix) and call_txi in @log_txis and
                 height == @log_kbi and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => ^logs} =
               conn |> with_store(store) |> get(prev_logs) |> json_response(200)
    end

    test "returns contract logs filtered by data of a contract", %{
      conn: conn,
      store: store,
      contract_pk: contract_pk
    } do
      contract_id = encode_contract(contract_pk)
      # data = "0xF4270"
      first_txi = @first_log_txi + 47
      data_prefix = ("0x" <> Integer.to_string(first_txi, 16)) |> String.slice(0, 6)
      limit = 6

      assert %{"data" => logs, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/logs", data: data_prefix, direction: :forward, limit: 6)
               |> json_response(200)

      assert length(logs) == limit
      assert ^logs = Enum.sort_by(logs, & &1["call_txi"])
      assert hd(logs)["call_txi"] == first_txi

      assert Enum.all?(logs, fn %{
                                  "data" => data,
                                  "contract_id" => ct_id,
                                  "call_txi" => call_txi,
                                  "height" => height,
                                  "micro_index" => micro_index,
                                  "block_hash" => block_hash
                                } ->
               String.starts_with?(data, data_prefix) and ct_id == contract_id and
                 call_txi in @log_txis and height == @log_kbi and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => next_logs, "prev" => prev_logs} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert length(next_logs) == limit
      assert ^next_logs = Enum.sort_by(next_logs, & &1["call_txi"])
      assert hd(next_logs)["call_txi"] == hd(logs)["call_txi"] + limit

      assert Enum.all?(next_logs, fn %{
                                       "data" => data,
                                       "call_txi" => call_txi,
                                       "height" => height,
                                       "micro_index" => micro_index,
                                       "block_hash" => block_hash
                                     } ->
               String.starts_with?(data, data_prefix) and call_txi in @log_txis and
                 height == @log_kbi and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => ^logs} =
               conn |> with_store(store) |> get(prev_logs) |> json_response(200)
    end

    test "returns contract logs filtered by event", %{
      conn: conn,
      store: store
    } do
      assert %{"data" => logs} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/logs", event: @evt2_ctor_name, direction: :forward)
               |> json_response(200)

      assert @default_limit = length(logs)
      assert ^logs = Enum.sort_by(logs, & &1["call_txi"])
      assert hd(logs)["call_txi"] == @first_log_txi + @evt1_amount

      assert Enum.all?(logs, fn %{
                                  "event_hash" => event_hash,
                                  "event_name" => nil,
                                  "call_txi" => call_txi,
                                  "height" => height,
                                  "micro_index" => micro_index,
                                  "block_hash" => block_hash
                                } ->
               event_hash == Base.hex_encode32(@evt2_hash) and
                 call_txi in @log_txis and height == @log_kbi and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)
    end

    test "returns contract logs filtered by contract and event", %{
      conn: conn,
      store: store,
      contract_pk: contract_pk
    } do
      contract_id = encode_contract(contract_pk)

      assert %{"data" => logs, "next" => next} =
               conn
               |> with_store(store)
               |> get(
                 "/v2/contracts/logs",
                 contract: contract_id,
                 event: @evt1_ctor_name,
                 direction: :forward
               )
               |> json_response(200)

      assert @default_limit = length(logs)
      assert ^logs = Enum.sort_by(logs, & &1["call_txi"])
      assert hd(logs)["call_txi"] == @first_log_txi + @mixed_logs_amount

      assert Enum.all?(logs, fn %{
                                  "contract_id" => ct_id,
                                  "call_txi" => call_txi,
                                  "height" => height,
                                  "event_hash" => event_hash,
                                  "event_name" => event_name,
                                  "micro_index" => micro_index,
                                  "block_hash" => block_hash
                                } ->
               ct_id == contract_id and call_txi in @log_txis and height == @log_kbi and
                 event_hash == Base.hex_encode32(@evt1_hash) and event_name == @evt1_ctor_name and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => next_logs, "prev" => prev_logs} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_logs)
      assert ^next_logs = Enum.sort_by(next_logs, & &1["call_txi"])
      assert hd(next_logs)["call_txi"] == @first_log_txi + @mixed_logs_amount + 10

      assert Enum.all?(next_logs, fn %{
                                       "contract_id" => ct_id,
                                       "call_txi" => call_txi,
                                       "height" => height,
                                       "event_hash" => event_hash,
                                       "event_name" => event_name,
                                       "micro_index" => micro_index,
                                       "block_hash" => block_hash
                                     } ->
               ct_id == contract_id and call_txi in @log_txis and height == @log_kbi and
                 event_hash == Base.hex_encode32(@evt1_hash) and event_name == @evt1_ctor_name and
                 micro_index == @log_mbi and
                 block_hash == encode(:micro_block_hash, @log_block_hash)
             end)

      assert %{"data" => ^logs} =
               conn |> with_store(store) |> get(prev_logs) |> json_response(200)
    end
  end

  describe "fetch_calls/5" do
    test "renders all saved internal calls with limit=100", %{
      conn: conn,
      store: store,
      contract_pk: contract_pk
    } do
      assert %{"data" => calls, "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/calls", limit: 100)
               |> json_response(200)

      assert length(calls) == @mixed_calls_amount + @contract_calls_amount + 2

      state = State.new(store)
      contract_create_txi = Origin.tx_index!(state, {:contract, contract_pk})

      Enum.each(calls, fn %{
                            "contract_txi" => contract_txi,
                            "contract_tx_hash" => contract_tx_hash,
                            "contract_id" => contract_id,
                            "call_txi" => call_txi,
                            "call_tx_hash" => call_tx_hash,
                            "function" => function,
                            "internal_tx" => internal_tx,
                            "height" => height,
                            "micro_index" => micro_index,
                            "block_hash" => block_hash,
                            "local_idx" => local_idx
                          } ->
        assert contract_txi == call_txi - 100 or contract_txi == contract_create_txi
        assert contract_tx_hash == encode(:tx_hash, <<contract_txi::256>>)
        assert contract_id == encode_contract(Origin.pubkey(state, {:contract, contract_txi}))
        assert call_tx_hash == encode(:tx_hash, <<call_txi::256>>)

        if call_txi == hd(calls)["call_txi"] do
          assert function == "Call.amount"
          assert internal_tx["payload"] == "ba_Q2FsbC5hbW91bnTau3mT"
        else
          assert function == @call_function
          assert internal_tx["payload"] == "ba_Q2hhaW4uc3BlbmRFa4Tl"
        end

        assert Map.delete(internal_tx, "payload") == %{
                 "amount" => 1_000_000_000_000_000_000,
                 "fee" => 0,
                 "nonce" => 0,
                 "recipient_id" => encode_account(<<call_txi::256>>),
                 "sender_id" => encode_account(@sender_pk),
                 "type" => "SpendTx",
                 "version" => 1
               }

        assert height == @call_kbi
        assert micro_index == @call_mbi
        assert block_hash == encode(:micro_block_hash, @call_block_hash)
        assert local_idx in 0..1
      end)
    end

    test "returns paginated contract calls by desc call txi", %{conn: conn, store: store} do
      assert %{"data" => calls, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/calls")
               |> json_response(200)

      assert @default_limit = length(calls)
      assert ^calls = Enum.sort_by(calls, & &1["call_txi"], :desc)
      assert hd(calls)["call_txi"] == @last_call_txi

      assert Enum.all?(calls, fn %{
                                   "call_txi" => call_txi,
                                   "height" => height,
                                   "micro_index" => micro_index,
                                   "block_hash" => block_hash
                                 } ->
               call_txi in @call_txis and height == @call_kbi and
                 micro_index == @call_mbi and
                 block_hash == encode(:micro_block_hash, @call_block_hash)
             end)

      assert %{"data" => next_calls, "prev" => prev_calls} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_calls)
      assert ^next_calls = Enum.sort_by(next_calls, & &1["call_txi"], :desc)
      assert hd(next_calls)["call_txi"] == @last_call_txi - 5

      assert Enum.all?(next_calls, fn %{
                                        "call_txi" => call_txi,
                                        "height" => height,
                                        "micro_index" => micro_index,
                                        "block_hash" => block_hash
                                      } ->
               call_txi in @call_txis and height == @call_kbi and
                 micro_index == @call_mbi and
                 block_hash == encode(:micro_block_hash, @call_block_hash)
             end)

      assert %{"data" => ^calls} =
               conn |> with_store(store) |> get(prev_calls) |> json_response(200)
    end

    test "returns paginated contract calls by asc call txi", %{conn: conn, store: store} do
      assert %{"data" => calls, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/calls", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(calls)
      assert ^calls = Enum.sort_by(calls, & &1["call_txi"])
      assert hd(calls)["call_txi"] == @first_call_txi

      assert Enum.all?(calls, fn %{
                                   "call_txi" => call_txi,
                                   "height" => height,
                                   "micro_index" => micro_index,
                                   "block_hash" => block_hash
                                 } ->
               call_txi in @call_txis and height == @call_kbi and
                 micro_index == @call_mbi and
                 block_hash == encode(:micro_block_hash, @call_block_hash)
             end)

      assert %{"data" => next_calls, "prev" => prev_calls} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_calls)
      assert ^next_calls = Enum.sort_by(next_calls, & &1["call_txi"])
      assert hd(next_calls)["call_txi"] == @first_call_txi + 5

      assert Enum.all?(next_calls, fn %{
                                        "call_txi" => call_txi,
                                        "height" => height,
                                        "micro_index" => micro_index,
                                        "block_hash" => block_hash
                                      } ->
               call_txi in @call_txis and height == @call_kbi and
                 micro_index == @call_mbi and
                 block_hash == encode(:micro_block_hash, @call_block_hash)
             end)

      assert %{"data" => ^calls} =
               conn |> with_store(store) |> get(prev_calls) |> json_response(200)
    end

    test "returns internal calls filtered by contract", %{
      conn: conn,
      store: store,
      contract_pk: contract_pk
    } do
      contract_id = encode_contract(contract_pk)

      assert %{"data" => calls, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/calls", contract: contract_id, direction: :forward)
               |> json_response(200)

      assert @default_limit == length(calls)
      assert ^calls = Enum.sort_by(calls, & &1["call_txi"])
      assert hd(calls)["call_txi"] == @first_call_txi + div(@mixed_calls_amount, 2)

      state = State.new(store)
      contract_create_txi = Origin.tx_index!(state, {:contract, contract_pk})

      Enum.each(calls, fn %{
                            "contract_txi" => contract_txi,
                            "contract_tx_hash" => contract_tx_hash,
                            "contract_id" => ct_id,
                            "call_txi" => call_txi,
                            "call_tx_hash" => call_tx_hash,
                            "function" => function,
                            "internal_tx" => internal_tx,
                            "height" => height,
                            "micro_index" => micro_index,
                            "block_hash" => block_hash,
                            "local_idx" => local_idx
                          } ->
        assert contract_txi == contract_create_txi
        assert contract_tx_hash == encode(:tx_hash, <<contract_txi::256>>)
        assert ct_id == contract_id
        assert call_tx_hash == encode(:tx_hash, <<call_txi::256>>)
        assert function == @call_function

        assert internal_tx == %{
                 "amount" => 1_000_000_000_000_000_000,
                 "fee" => 0,
                 "nonce" => 0,
                 "payload" => "ba_Q2hhaW4uc3BlbmRFa4Tl",
                 "recipient_id" => encode_account(<<call_txi::256>>),
                 "sender_id" => encode_account(@sender_pk),
                 "type" => "SpendTx",
                 "version" => 1
               }

        assert height == @call_kbi
        assert micro_index == @call_mbi
        assert block_hash == encode(:micro_block_hash, @call_block_hash)
        assert local_idx in 0..1
      end)

      assert %{"data" => next_calls, "prev" => prev_calls} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_calls)
      assert ^next_calls = Enum.sort_by(next_calls, & &1["call_txi"])
      assert hd(next_calls)["call_txi"] == hd(calls)["call_txi"] + 5

      assert Enum.all?(next_calls, fn %{
                                        "contract_id" => ct_id,
                                        "call_txi" => call_txi,
                                        "height" => height,
                                        "micro_index" => micro_index,
                                        "block_hash" => block_hash
                                      } ->
               ct_id == contract_id and call_txi in @call_txis and height == @call_kbi and
                 micro_index == @call_mbi and
                 block_hash == encode(:micro_block_hash, @call_block_hash)
             end)

      assert %{"data" => ^calls} =
               conn |> with_store(store) |> get(prev_calls) |> json_response(200)
    end

    test "returns internal calls filtered by contract and SpendTx recipient_id", %{
      conn: conn,
      store: store,
      contract_pk: contract_pk
    } do
      contract_id = encode_contract(contract_pk)
      expected_call_txi = @first_call_txi + div(@mixed_calls_amount, 2)
      recipient_id = encode_account(<<expected_call_txi::256>>)

      assert %{"data" => calls, "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/calls", contract: contract_id, recipient_id: recipient_id)
               |> json_response(200)

      state = State.new(store)
      contract_create_txi = Origin.tx_index!(state, {:contract, contract_pk})

      Enum.each(calls, fn %{
                            "contract_txi" => contract_txi,
                            "contract_tx_hash" => contract_tx_hash,
                            "contract_id" => ct_id,
                            "call_txi" => call_txi,
                            "call_tx_hash" => call_tx_hash,
                            "function" => function,
                            "internal_tx" => internal_tx,
                            "height" => height,
                            "micro_index" => micro_index,
                            "block_hash" => block_hash,
                            "local_idx" => local_idx
                          } ->
        assert contract_txi == contract_create_txi
        assert contract_tx_hash == encode(:tx_hash, <<contract_txi::256>>)
        assert ct_id == contract_id
        assert call_txi == expected_call_txi
        assert call_tx_hash == encode(:tx_hash, <<call_txi::256>>)
        assert function == @call_function

        assert internal_tx == %{
                 "amount" => 1_000_000_000_000_000_000,
                 "fee" => 0,
                 "nonce" => 0,
                 "payload" => "ba_Q2hhaW4uc3BlbmRFa4Tl",
                 "recipient_id" => encode_account(<<call_txi::256>>),
                 "sender_id" => encode_account(@sender_pk),
                 "type" => "SpendTx",
                 "version" => 1
               }

        assert height == @call_kbi
        assert micro_index == @call_mbi
        assert block_hash == encode(:micro_block_hash, @call_block_hash)
        assert local_idx in 0..1
      end)
    end

    test "returns internal calls filtered by SpendTx recipient_id", %{
      conn: conn,
      store: store
    } do
      expected_call_txi = @first_call_txi + 1
      recipient_id = encode_account(<<expected_call_txi::256>>)

      assert %{"data" => calls, "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/calls", recipient_id: recipient_id)
               |> json_response(200)

      state = State.new(store)
      contract_pk = Origin.pubkey(state, {:contract, expected_call_txi - 100})
      contract_create_txi = Origin.tx_index!(state, {:contract, contract_pk})

      Enum.each(calls, fn %{
                            "contract_txi" => contract_txi,
                            "contract_tx_hash" => contract_tx_hash,
                            "contract_id" => ct_id,
                            "call_txi" => call_txi,
                            "call_tx_hash" => call_tx_hash,
                            "function" => function,
                            "internal_tx" => internal_tx,
                            "height" => height,
                            "micro_index" => micro_index,
                            "block_hash" => block_hash,
                            "local_idx" => local_idx
                          } ->
        assert contract_txi == contract_create_txi
        assert contract_tx_hash == encode(:tx_hash, <<contract_txi::256>>)
        assert ct_id == encode_contract(contract_pk)
        assert call_txi == expected_call_txi
        assert call_tx_hash == encode(:tx_hash, <<call_txi::256>>)
        assert function == @call_function

        assert internal_tx == %{
                 "amount" => 1_000_000_000_000_000_000,
                 "fee" => 0,
                 "nonce" => 0,
                 "payload" => "ba_Q2hhaW4uc3BlbmRFa4Tl",
                 "recipient_id" => encode_account(<<call_txi::256>>),
                 "sender_id" => encode_account(@sender_pk),
                 "type" => "SpendTx",
                 "version" => 1
               }

        assert height == @call_kbi
        assert micro_index == @call_mbi
        assert block_hash == encode(:micro_block_hash, @call_block_hash)
        assert local_idx in 0..1
      end)
    end

    test "returns internal calls filtered by function prefix", %{
      conn: conn,
      store: store
    } do
      fname_prefix = "Chain.sp"

      assert %{"data" => calls, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/calls", function: fname_prefix)
               |> json_response(200)

      assert Enum.all?(calls, fn %{
                                   "function" => function,
                                   "call_txi" => call_txi,
                                   "height" => height,
                                   "micro_index" => micro_index,
                                   "block_hash" => block_hash
                                 } ->
               String.starts_with?(function, fname_prefix) and call_txi in @call_txis and
                 height == @call_kbi and
                 micro_index == @call_mbi and
                 block_hash == encode(:micro_block_hash, @call_block_hash)
             end)

      assert 10 = length(calls)

      assert %{"data" => next_calls, "prev" => prev_calls} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert Enum.all?(next_calls, fn %{
                                        "function" => function,
                                        "call_txi" => call_txi,
                                        "height" => height,
                                        "micro_index" => micro_index,
                                        "block_hash" => block_hash
                                      } ->
               String.starts_with?(function, fname_prefix) and call_txi in @call_txis and
                 height == @call_kbi and
                 micro_index == @call_mbi and
                 block_hash == encode(:micro_block_hash, @call_block_hash)
             end)

      assert %{"data" => ^calls} =
               conn |> with_store(store) |> get(prev_calls) |> json_response(200)
    end
  end

  describe "contracts" do
    test "it returns latests contracts in backwards order", %{conn: conn, store: store} do
      [txi1, txi2, txi3, txi4] = [1, 2, 3, 4]
      [tx_hash1, tx_hash2, tx_hash3, tx_hash4] = [<<1::256>>, <<2::256>>, <<3::256>>, <<4::256>>]
      enc_tx_hash1 = Enc.encode(:tx_hash, tx_hash1)
      enc_tx_hash2 = Enc.encode(:tx_hash, tx_hash2)
      enc_tx_hash3 = Enc.encode(:tx_hash, tx_hash3)
      enc_tx_hash4 = Enc.encode(:tx_hash, tx_hash4)
      owner_pk = <<4::256>>
      owner_id = :aeser_id.create(:account, owner_pk)
      enc_owner_id = Enc.encode(:account_pubkey, owner_pk)

      store =
        store
        |> Store.put(Model.Type, Model.type(index: {:contract_create_tx, txi1}))
        |> Store.put(Model.Tx, Model.tx(index: txi1, id: tx_hash1))
        |> Store.put(
          Model.FnameIntContractCall,
          Model.fname_int_contract_call(index: {"Chain.clone", txi2, 0})
        )
        |> Store.put(Model.Tx, Model.tx(index: txi2, id: tx_hash2))
        |> Store.put(Model.Type, Model.type(index: {:contract_create_tx, txi3}))
        |> Store.put(Model.Tx, Model.tx(index: txi3, id: tx_hash3))
        |> Store.put(Model.Type, Model.type(index: {:ga_attach_tx, txi4}))
        |> Store.put(Model.Tx, Model.tx(index: txi4, id: tx_hash4))

      block_hash = <<10::256>>
      enc_block_hash = Enc.encode(:micro_block_hash, block_hash)

      {:ok, contract_create_aetx1} =
        :aect_create_tx.new(%{
          owner_id: owner_id,
          nonce: 1,
          code: "code-1",
          vm_version: 7,
          abi_version: 3,
          fee: 11,
          deposit: 111,
          amount: 1_111,
          gas: 11_111,
          gas_price: 111_111,
          call_data: <<>>,
          ttl: 1_111_111
        })

      {:ok, contract_create_aetx2} =
        :aect_create_tx.new(%{
          owner_id: owner_id,
          nonce: 2,
          code: "code-2",
          vm_version: 7,
          abi_version: 3,
          fee: 22,
          deposit: 222,
          amount: 2_222,
          gas: 22_222,
          gas_price: 222_222,
          call_data: <<>>,
          ttl: 2_222_222
        })

      {:ok, contract_create_aetx3} =
        :aect_create_tx.new(%{
          owner_id: owner_id,
          nonce: 3,
          code: "code-3",
          vm_version: 7,
          abi_version: 3,
          fee: 33,
          deposit: 333,
          amount: 3_333,
          gas: 33_333,
          gas_price: 333_333,
          call_data: <<>>,
          ttl: 3_333_333
        })

      {:ok, ga_attach_aetx} =
        :aega_attach_tx.new(%{
          owner_id: owner_id,
          nonce: 4,
          code: "code-4",
          auth_fun: "auth-fun",
          vm_version: 7,
          abi_version: 4,
          fee: 44,
          gas: 44_444,
          gas_price: 444_444,
          call_data: <<>>
        })

      {:contract_create_tx, contract_create_tx1} = :aetx.specialize_type(contract_create_aetx1)
      {:contract_create_tx, contract_create_tx2} = :aetx.specialize_type(contract_create_aetx2)
      {:contract_create_tx, contract_create_tx3} = :aetx.specialize_type(contract_create_aetx3)
      {:ga_attach_tx, ga_attach_tx} = :aetx.specialize_type(ga_attach_aetx)

      with_mocks [
        {DbUtil, [:passthrough],
         [
           read_node_tx_details: fn
             _state, {^txi1, -1} ->
               {contract_create_tx1, :contract_create_tx, tx_hash1, :contract_create_tx,
                block_hash}

             _state, {^txi2, 0} ->
               {contract_create_tx2, :contract_create_tx, tx_hash2, :contract_call_tx, block_hash}

             _state, {^txi3, -1} ->
               {contract_create_tx3, :contract_create_tx, tx_hash3, :contract_create_tx,
                block_hash}

             _state, {^txi4, -1} ->
               {ga_attach_tx, :ga_attach_tx, tx_hash4, :ga_attach_tx, block_hash}
           end
         ]}
      ] do
        assert %{"data" => [contract4, contract3], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/contracts", limit: 2)
                 |> json_response(200)

        assert %{
                 "block_hash" => ^enc_block_hash,
                 "source_tx_hash" => ^enc_tx_hash4,
                 "source_tx_type" => "GAAttachTx",
                 "create_tx" => %{
                   "fee" => 44,
                   "owner_id" => ^enc_owner_id
                 }
               } = contract4

        assert %{
                 "block_hash" => ^enc_block_hash,
                 "source_tx_hash" => ^enc_tx_hash3,
                 "source_tx_type" => "ContractCreateTx",
                 "create_tx" => %{
                   "amount" => 3_333,
                   "owner_id" => ^enc_owner_id
                 }
               } = contract3

        assert %{"data" => [contract2, contract1], "next" => nil} =
                 conn
                 |> with_store(store)
                 |> get(next_url)
                 |> json_response(200)

        assert %{
                 "block_hash" => ^enc_block_hash,
                 "source_tx_hash" => ^enc_tx_hash2,
                 "source_tx_type" => "ContractCallTx",
                 "create_tx" => %{
                   "amount" => 2_222,
                   "owner_id" => ^enc_owner_id
                 }
               } = contract2

        assert %{
                 "block_hash" => ^enc_block_hash,
                 "source_tx_hash" => ^enc_tx_hash1,
                 "source_tx_type" => "ContractCreateTx",
                 "create_tx" => %{
                   "amount" => 1_111,
                   "owner_id" => ^enc_owner_id
                 }
               } = contract1
      end
    end
  end

  describe "contract" do
    test "when contract is created on an internal call, it returns 200", %{
      conn: conn,
      store: store
    } do
      txi = 1
      tx_hash = <<1::256>>
      enc_tx_hash = Enc.encode(:tx_hash, tx_hash)
      owner_pk = <<4::256>>
      owner_id = :aeser_id.create(:account, owner_pk)
      enc_owner_id = :aeser_api_encoder.encode(:account_pubkey, owner_pk)
      account_pk = <<5::256>>
      account_id = :aeser_id.create(:account, account_pk)
      block_hash = <<10::256>>
      enc_block_hash = Enc.encode(:micro_block_hash, block_hash)

      {:ok, contract_create_aetx} =
        :aect_create_tx.new(%{
          owner_id: owner_id,
          nonce: 1,
          code: "code-1",
          vm_version: 7,
          abi_version: 3,
          fee: 11,
          deposit: 111,
          amount: 1_111,
          gas: 11_111,
          gas_price: 111_111,
          call_data: <<>>,
          ttl: 1_111_111
        })

      {:contract_create_tx, contract_create_tx} = :aetx.specialize_type(contract_create_aetx)
      contract_pk = :aect_create_tx.contract_pubkey(contract_create_tx)
      contract_id = :aeser_id.create(:contract, contract_pk)
      encoded_contract_id = Enc.encode(:contract_pubkey, contract_pk)

      {:ok, contract_call_aetx} =
        :aect_call_tx.new(%{
          caller_id: account_id,
          nonce: 2,
          contract_id: contract_id,
          abi_version: 2,
          fee: 1,
          amount: 1,
          gas: 1,
          gas_price: 1,
          call_data: ""
        })

      store =
        store
        |> Store.put(Model.Type, Model.type(index: {:contract_call_tx, txi}))
        |> Store.put(Model.Tx, Model.tx(index: txi, id: tx_hash))
        |> Store.put(
          Model.IntContractCall,
          Model.int_contract_call(index: {txi, 0}, fname: "Chain.clone")
        )
        |> Store.put(
          Model.FnameIntContractCall,
          Model.fname_int_contract_call(index: {"Chain.clone", txi, 0})
        )
        |> Store.put(Model.Field, Model.field(index: {:contract_call_tx, nil, contract_pk, txi}))

      with_mocks [
        {DbUtil, [:passthrough],
         [
           read_node_tx_details: fn _state, {^txi, 0} ->
             {contract_create_tx, :contract_create_tx, tx_hash, :contract_call_tx, block_hash}
           end,
           read_node_tx: fn _state, {^txi, 0} ->
             contract_create_tx
           end
         ]},
        {Db, [:passthrough],
         [
           get_signed_tx: fn ^tx_hash -> :aetx_sign.new(contract_call_aetx, []) end
         ]}
      ] do
        assert %{
                 "block_hash" => ^enc_block_hash,
                 "source_tx_hash" => ^enc_tx_hash,
                 "source_tx_type" => "ContractCallTx",
                 "create_tx" => %{
                   "amount" => 1_111,
                   "owner_id" => ^enc_owner_id
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/contracts/#{encoded_contract_id}")
                 |> json_response(200)
      end
    end

    test "when contract is created in a raw tx, it returns 200", %{
      conn: conn,
      store: store
    } do
      txi = 1
      tx_hash = <<1::256>>
      enc_tx_hash = Enc.encode(:tx_hash, tx_hash)
      owner_pk = <<4::256>>
      owner_id = :aeser_id.create(:account, owner_pk)
      enc_owner_id = :aeser_api_encoder.encode(:account_pubkey, owner_pk)
      contract_pk = <<5::256>>
      encoded_contract_id = Enc.encode(:contract_pubkey, contract_pk)

      store =
        store
        |> Store.put(Model.Type, Model.type(index: {:contract_create_tx, txi}))
        |> Store.put(Model.Tx, Model.tx(index: txi, id: tx_hash))
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, txi})
        )

      block_hash = <<10::256>>
      enc_block_hash = Enc.encode(:micro_block_hash, block_hash)

      {:ok, contract_create_aetx} =
        :aect_create_tx.new(%{
          owner_id: owner_id,
          nonce: 1,
          code: "code-1",
          vm_version: 7,
          abi_version: 3,
          fee: 11,
          deposit: 111,
          amount: 1_111,
          gas: 11_111,
          gas_price: 111_111,
          call_data: <<>>,
          ttl: 1_111_111
        })

      {:contract_create_tx, contract_create_tx} = :aetx.specialize_type(contract_create_aetx)

      with_mocks [
        {DbUtil, [:passthrough],
         [
           read_node_tx_details: fn _state, {^txi, -1} ->
             {contract_create_tx, :contract_create_tx, tx_hash, :contract_create_tx, block_hash}
           end
         ]},
        {Db, [:passthrough],
         [
           get_signed_tx: fn ^tx_hash -> :aetx_sign.new(contract_create_aetx, []) end
         ]}
      ] do
        assert %{
                 "block_hash" => ^enc_block_hash,
                 "source_tx_hash" => ^enc_tx_hash,
                 "source_tx_type" => "ContractCreateTx",
                 "create_tx" => %{
                   "amount" => 1_111,
                   "owner_id" => ^enc_owner_id
                 }
               } =
                 conn
                 |> with_store(store)
                 |> get("/v2/contracts/#{encoded_contract_id}")
                 |> json_response(200)
      end
    end
  end

  defp logs_setup(store, contract_pk, aex9_contract_pk, aex141_contract_pk) do
    block_index1 = {100, 1}
    block_index2 = {@log_kbi, @log_mbi}

    store =
      store
      |> Store.put(
        Model.Block,
        Model.block(index: block_index1, hash: :crypto.strong_rand_bytes(32))
      )
      |> Store.put(
        Model.Block,
        Model.block(index: block_index2, hash: @log_block_hash)
      )

    last_log_txi = @first_log_txi + @mixed_logs_amount - 1

    store =
      Enum.reduce(@first_log_txi..last_log_txi, store, fn txi, store ->
        create_txi = txi - 100
        evt_hash = if txi < @first_log_txi + @evt1_amount, do: @evt1_hash, else: @evt2_hash
        data = "0x" <> Integer.to_string(txi, 16)
        idx = rem(txi, 5)
        contract_pk = :crypto.strong_rand_bytes(32)

        m_log =
          Model.contract_log(
            index: {create_txi, txi, evt_hash, idx},
            ext_contract: contract_pk,
            args: [<<txi::256>>],
            data: data
          )

        m_data_log = Model.data_contract_log(index: {data, txi, create_txi, evt_hash, idx})
        m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, create_txi, idx})
        m_ctevt_log = Model.ctevt_contract_log(index: {evt_hash, txi, create_txi, idx})
        m_idx_log = Model.idx_contract_log(index: {txi, idx, create_txi, evt_hash})

        store
        |> Store.put(
          Model.Tx,
          Model.tx(index: create_txi, id: <<create_txi::256>>, block_index: block_index1)
        )
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>, block_index: block_index2))
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
        )
        |> Store.put(
          Model.RevOrigin,
          Model.rev_origin(index: {create_txi, :contract_create_tx, contract_pk})
        )
        |> Store.put(Model.ContractLog, m_log)
        |> Store.put(Model.DataContractLog, m_data_log)
        |> Store.put(Model.EvtContractLog, m_evt_log)
        |> Store.put(Model.CtEvtContractLog, m_ctevt_log)
        |> Store.put(Model.IdxContractLog, m_idx_log)
      end)

    first_log_txi = last_log_txi + 1
    create_txi = first_log_txi - 100
    last_log_txi = first_log_txi + @contract_logs_amount

    store =
      Enum.reduce(first_log_txi..last_log_txi, store, fn txi, store ->
        evt_hash = @evt1_hash
        data = "0x" <> Integer.to_string(txi, 16)
        idx = rem(txi, 5)

        m_log =
          Model.contract_log(
            index: {create_txi, txi, evt_hash, idx},
            ext_contract: contract_pk,
            args: [<<txi::256>>],
            data: data
          )

        m_data_log = Model.data_contract_log(index: {data, txi, create_txi, evt_hash, idx})
        m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, create_txi, idx})
        m_ctevt_log = Model.ctevt_contract_log(index: {evt_hash, create_txi, txi, idx})
        m_idx_log = Model.idx_contract_log(index: {txi, idx, create_txi, evt_hash})

        store
        |> Store.put(
          Model.Tx,
          Model.tx(index: create_txi, id: <<create_txi::256>>, block_index: block_index1)
        )
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>, block_index: block_index2))
        |> Store.put(Model.ContractLog, m_log)
        |> Store.put(Model.DataContractLog, m_data_log)
        |> Store.put(Model.EvtContractLog, m_evt_log)
        |> Store.put(Model.CtEvtContractLog, m_ctevt_log)
        |> Store.put(Model.IdxContractLog, m_idx_log)
      end)

    store =
      store
      |> Store.put(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
      )
      |> Store.put(
        Model.RevOrigin,
        Model.rev_origin(index: {create_txi, :contract_create_tx, contract_pk})
      )

    first_log_txi = last_log_txi + 1
    create_txi = first_log_txi - 100

    store =
      @aex9_events
      |> Enum.with_index(first_log_txi)
      |> Enum.reduce(store, fn {event_name, txi}, store ->
        evt_hash = :aec_hash.blake2b_256_hash(event_name)
        data = "0x" <> Integer.to_string(txi, 16)
        idx = rem(txi, 5)

        fake_args =
          if event_name == "Burn" do
            [<<1::256>>, <<txi::256>>]
          else
            [<<txi::256>>]
          end

        m_log =
          Model.contract_log(
            index: {create_txi, txi, evt_hash, idx},
            ext_contract: aex9_contract_pk,
            args: fake_args,
            data: data
          )

        m_data_log = Model.data_contract_log(index: {data, txi, create_txi, evt_hash, idx})
        m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, create_txi, idx})
        m_ctevt_log = Model.ctevt_contract_log(index: {evt_hash, txi, create_txi, idx})
        m_idx_log = Model.idx_contract_log(index: {txi, idx, create_txi, evt_hash})

        store
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>, block_index: block_index2))
        |> Store.put(Model.ContractLog, m_log)
        |> Store.put(Model.DataContractLog, m_data_log)
        |> Store.put(Model.EvtContractLog, m_evt_log)
        |> Store.put(Model.CtEvtContractLog, m_ctevt_log)
        |> Store.put(Model.IdxContractLog, m_idx_log)
      end)

    store =
      store
      |> Store.put(
        Model.Tx,
        Model.tx(index: create_txi, id: <<create_txi::256>>, block_index: block_index1)
      )
      |> Store.put(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, aex9_contract_pk, create_txi})
      )
      |> Store.put(
        Model.RevOrigin,
        Model.rev_origin(index: {create_txi, :contract_create_tx, aex9_contract_pk})
      )

    first_log_txi = first_log_txi + length(@aex9_events)
    create_txi = first_log_txi - 100

    store =
      @aex141_events
      |> Enum.with_index(first_log_txi)
      |> Enum.reduce(store, fn {event_name, txi}, store ->
        evt_hash = :aec_hash.blake2b_256_hash(event_name)
        data = "0x" <> Integer.to_string(txi, 16)
        idx = rem(txi, 5)

        fake_args =
          if event_name == "Burn" do
            [<<1::256>>, <<txi::256>>]
          else
            [<<txi::256>>]
          end

        m_log =
          Model.contract_log(
            index: {create_txi, txi, evt_hash, idx},
            ext_contract: aex141_contract_pk,
            args: fake_args,
            data: data
          )

        m_data_log = Model.data_contract_log(index: {data, txi, create_txi, evt_hash, idx})
        m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, create_txi, idx})
        m_ctevt_log = Model.ctevt_contract_log(index: {evt_hash, txi, create_txi, idx})
        m_idx_log = Model.idx_contract_log(index: {txi, idx, create_txi, evt_hash})

        store
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>, block_index: block_index2))
        |> Store.put(Model.ContractLog, m_log)
        |> Store.put(Model.DataContractLog, m_data_log)
        |> Store.put(Model.EvtContractLog, m_evt_log)
        |> Store.put(Model.CtEvtContractLog, m_ctevt_log)
        |> Store.put(Model.IdxContractLog, m_idx_log)
      end)

    store
    |> Store.put(
      Model.Tx,
      Model.tx(
        index: create_txi,
        id: <<create_txi::256>>,
        block_index: block_index1
      )
    )
    |> Store.put(
      Model.Field,
      Model.field(index: {:contract_create_tx, nil, aex141_contract_pk, create_txi})
    )
    |> Store.put(
      Model.RevOrigin,
      Model.rev_origin(index: {create_txi, :contract_create_tx, aex141_contract_pk})
    )
  end

  defp calls_setup(store, contract_pk) do
    block_index1 = {200, 1}
    block_index2 = {@call_kbi, @call_mbi}

    store =
      store
      |> Store.put(
        Model.Block,
        Model.block(index: block_index1, hash: :crypto.strong_rand_bytes(32))
      )
      |> Store.put(
        Model.Block,
        Model.block(index: block_index2, hash: @call_block_hash)
      )

    last_call_txi = @first_call_txi + div(@mixed_calls_amount, 2) - 1

    {mixed_ct_mutations, store} =
      Enum.map_reduce(@first_call_txi..last_call_txi, store, fn call_txi, store ->
        int_calls =
          Enum.map(0..1, fn i ->
            tx =
              {:aetx, :spend_tx, :aec_spend_tx, i,
               {:spend_tx, {:id, :account, @sender_pk}, {:id, :account, <<call_txi::256>>},
                1_000_000_000_000_000_000, 0, 0, 0, @call_function}}

            {tx_type, raw_tx} = :aetx.specialize_type(tx)

            {i, @call_function, tx_type, tx, raw_tx}
          end)

        contract_pk = :crypto.strong_rand_bytes(32)
        create_txi = call_txi - 100

        store =
          store
          |> Store.put(
            Model.Field,
            Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
          )
          |> Store.put(
            Model.RevOrigin,
            Model.rev_origin(index: {create_txi, :contract_create_tx, contract_pk})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: call_txi, id: <<call_txi::256>>, block_index: block_index2)
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: create_txi, id: <<create_txi::256>>, block_index: block_index2)
          )

        {IntCallsMutation.new(contract_pk, call_txi, int_calls), store}
      end)

    first_txi = last_call_txi + 1
    last_txi = first_txi + div(@contract_calls_amount, 2) - 1

    {contract_mutations, store} =
      Enum.map_reduce(first_txi..last_txi, store, fn call_txi, store ->
        int_calls =
          Enum.map(0..1, fn i ->
            tx =
              {:aetx, :spend_tx, :aec_spend_tx, i,
               {:spend_tx, {:id, :account, @sender_pk}, {:id, :account, <<call_txi::256>>},
                1_000_000_000_000_000_000, 0, 0, 0, @call_function}}

            {tx_type, raw_tx} = :aetx.specialize_type(tx)

            {i, @call_function, tx_type, tx, raw_tx}
          end)

        store =
          Store.put(
            store,
            Model.Tx,
            Model.tx(index: call_txi, id: <<call_txi::256>>, block_index: block_index2)
          )

        {IntCallsMutation.new(contract_pk, call_txi, int_calls), store}
      end)

    not_spend_txi = last_txi + 1

    not_spend_int_calls =
      Enum.map(0..1, fn i ->
        tx =
          {:aetx, :spend_tx, :aec_spend_tx, i,
           {:spend_tx, {:id, :account, @sender_pk}, {:id, :account, <<not_spend_txi::256>>},
            1_000_000_000_000_000_000, 0, 0, 0, "Call.amount"}}

        {tx_type, raw_tx} = :aetx.specialize_type(tx)

        {i, "Call.amount", tx_type, tx, raw_tx}
      end)

    extra_ct_pk = :crypto.strong_rand_bytes(32)
    create_txi = not_spend_txi - 100

    store =
      store
      |> Store.put(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, extra_ct_pk, create_txi})
      )
      |> Store.put(
        Model.RevOrigin,
        Model.rev_origin(index: {create_txi, :contract_create_tx, extra_ct_pk})
      )
      |> Store.put(
        Model.Tx,
        Model.tx(index: create_txi, id: <<create_txi::256>>, block_index: block_index2)
      )
      |> Store.put(
        Model.Tx,
        Model.tx(index: not_spend_txi, id: <<not_spend_txi::256>>, block_index: block_index2)
      )

    extra_mutation = IntCallsMutation.new(extra_ct_pk, not_spend_txi, not_spend_int_calls)

    change_store(store, mixed_ct_mutations ++ contract_mutations ++ [extra_mutation])
  end
end
