defmodule AeMdwWeb.Controllers.ContractControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Origin
  alias AeMdw.Txs

  require Model

  @default_limit 10

  @evt1_hash :crypto.strong_rand_bytes(32)
  @evt2_ctor_name "evt2_hash"
  @evt2_hash :aec_hash.blake2b_256_hash(@evt2_ctor_name)
  @event_hashes [Base.hex_encode32(@evt1_hash), Base.hex_encode32(@evt2_hash)]

  @log_kbi 101
  @log_mbi 1
  @log_block_hash :crypto.strong_rand_bytes(32)
  @first_log_txi 1_000_001
  @evt1_amount 20
  @mixed_logs_amount 40
  @contract_logs_amount 20
  @last_log_txi @first_log_txi + @mixed_logs_amount + @contract_logs_amount - 1
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

    store =
      NullStore.new()
      |> MemStore.new()
      |> logs_setup(contract_pk)
      |> calls_setup(contract_pk)

    [store: store, contract_pk: contract_pk]
  end

  describe "fetch_logs/5" do
    test "renders all saved contract logs with limit=100", %{
      conn: conn,
      store: store,
      contract_pk: contract_pk
    } do
      assert %{"data" => logs, "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/logs", limit: 100)
               |> json_response(200)

      assert @mixed_logs_amount + @contract_logs_amount == length(logs)

      state = State.new(store)
      contract_create_txi = Origin.tx_index!(state, {:contract, contract_pk})

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
                           "height" => height,
                           "micro_index" => micro_index,
                           "block_hash" => block_hash,
                           "log_idx" => log_idx
                         } ->
        assert create_txi == call_txi - 100 or create_txi == contract_create_txi
        assert contract_tx_hash == encode(:tx_hash, Txs.txi_to_hash(state, create_txi))
        assert contract_id == encode_contract(Origin.pubkey(state, {:contract, create_txi}))
        assert call_tx_hash == encode(:tx_hash, Txs.txi_to_hash(state, call_txi))
        assert args == [to_string(call_txi)]
        assert data == "0x" <> Integer.to_string(call_txi, 16)
        assert event_hash in @event_hashes
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

    test "returns internal calls filtered by function", %{
      conn: conn,
      store: store
    } do
      fname = "Chain.spend"

      assert %{"data" => calls, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/contracts/calls", function: fname)
               |> json_response(200)

      assert Enum.all?(calls, fn %{
                                   "function" => function,
                                   "call_txi" => call_txi,
                                   "height" => height,
                                   "micro_index" => micro_index,
                                   "block_hash" => block_hash
                                 } ->
               function == fname and call_txi in @call_txis and
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
               function == fname and call_txi in @call_txis and
                 height == @call_kbi and
                 micro_index == @call_mbi and
                 block_hash == encode(:micro_block_hash, @call_block_hash)
             end)

      assert %{"data" => ^calls} =
               conn |> with_store(store) |> get(prev_calls) |> json_response(200)
    end

    test "when filtering by function name and scope, it returns an error", %{conn: conn} do
      error_msg = "invalid scope: can't scope when filtering by function"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/contracts/calls", function: "asd", scope: "gen:0-1")
               |> json_response(400)
    end
  end

  defp logs_setup(store, contract_pk) do
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
        |> Store.put(Model.IdxContractLog, m_idx_log)
      end)

    create_txi = last_log_txi + 1 - 100

    store =
      Enum.reduce((last_log_txi + 1)..(last_log_txi + @contract_logs_amount), store, fn txi,
                                                                                        store ->
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
        |> Store.put(Model.IdxContractLog, m_idx_log)
      end)

    store
    |> Store.put(
      Model.Field,
      Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
    )
    |> Store.put(
      Model.RevOrigin,
      Model.rev_origin(index: {create_txi, :contract_create_tx, contract_pk})
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

            {@call_function, tx_type, tx, raw_tx}
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

            {@call_function, tx_type, tx, raw_tx}
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

        {"Call.amount", tx_type, tx, raw_tx}
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
