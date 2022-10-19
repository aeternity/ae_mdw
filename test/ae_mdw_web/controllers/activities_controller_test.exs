defmodule AeMdwWeb.ActivitiesControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Format
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Store
  alias AeMdw.Node.Db
  alias AeMdw.TestSamples, as: TS

  import Mock

  require Model

  describe "account_activities" do
    test "it returns all transaction events that have the account on any field", %{conn: conn} do
      account_pk = TS.address(0)
      next_account_pk = TS.address(1)
      account = Enc.encode(:account_pubkey, account_pk)
      account_id = :aeser_id.create(:account, account_pk)
      height = 398
      mbi = 2

      {:ok, aetx} =
        :aec_spend_tx.new(%{
          sender_id: account_id,
          recipient_id: account_id,
          amount: 2,
          fee: 3,
          nonce: 4,
          payload: ""
        })

      {:spend_tx, tx} = :aetx.specialize_type(aetx)

      store =
        empty_store()
        |> Store.put(Model.Field, Model.field(index: {:contract_call_tx, 1, account_pk, 1}))
        |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {height, mbi}))
        |> Store.put(Model.Field, Model.field(index: {:contract_call_tx, 1, account_pk, 2}))
        |> Store.put(Model.Tx, Model.tx(index: 2, block_index: {height, mbi}))
        |> Store.put(Model.Field, Model.field(index: {:contract_call_tx, 1, account_pk, 3}))
        |> Store.put(Model.Tx, Model.tx(index: 3, block_index: {height, mbi}))
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, next_account_pk, 4})
        )

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn _tx_hash ->
             {"", :spend_tx, aetx, tx}
           end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :header end]},
        {:aetx_sign, [], [serialize_for_client: fn :header, ^aetx -> %{} end]}
      ] do
        assert %{"prev" => nil, "data" => [tx3, tx2, tx1], "next" => _next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/accounts/#{account}/activities")
                 |> json_response(200)

        assert %{
                 "height" => ^height,
                 "type" => "ContractCallTxEvent",
                 "payload" => %{"micro_index" => ^mbi}
               } = tx1

        assert %{
                 "height" => ^height,
                 "type" => "ContractCallTxEvent",
                 "payload" => %{"micro_index" => ^mbi}
               } = tx2

        assert %{
                 "height" => ^height,
                 "type" => "ContractCallTxEvent",
                 "payload" => %{"micro_index" => ^mbi}
               } = tx3
      end
    end

    test "it returns all transaction events that have the account on any field forward with limit = 2",
         %{conn: conn} do
      account_pk = TS.address(0)
      account = Enc.encode(:account_pubkey, account_pk)
      account_id = :aeser_id.create(:account, account_pk)
      height = 398
      mbi = 2

      {:ok, aetx} =
        :aec_spend_tx.new(%{
          sender_id: account_id,
          recipient_id: account_id,
          amount: 2,
          fee: 3,
          nonce: 4,
          payload: ""
        })

      {:spend_tx, tx} = :aetx.specialize_type(aetx)

      store =
        empty_store()
        |> Store.put(Model.Field, Model.field(index: {:contract_call_tx, 1, account_pk, 1}))
        |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {height, mbi}, id: "hash1"))
        |> Store.put(Model.Field, Model.field(index: {:contract_call_tx, 1, account_pk, 2}))
        |> Store.put(Model.Tx, Model.tx(index: 2, block_index: {height, mbi}, id: "hash2"))
        |> Store.put(Model.Field, Model.field(index: {:contract_call_tx, 1, account_pk, 3}))
        |> Store.put(Model.Tx, Model.tx(index: 3, block_index: {height, mbi}, id: "hash3"))

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             "hash1" ->
               {"", :spend_tx, aetx, tx}

             "hash2" ->
               {"", :spend_tx, aetx, tx}
           end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :header end]},
        {:aetx_sign, [], [serialize_for_client: fn :header, ^aetx -> %{} end]}
      ] do
        assert %{"prev" => nil, "data" => [tx1, tx2], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/accounts/#{account}/activities", direction: "forward", limit: 2)
                 |> json_response(200)

        assert %{
                 "height" => ^height,
                 "type" => "ContractCallTxEvent",
                 "payload" => %{"micro_index" => ^mbi}
               } = tx1

        assert %{
                 "height" => ^height,
                 "type" => "ContractCallTxEvent",
                 "payload" => %{"micro_index" => ^mbi}
               } = tx2

        assert %URI{query: query} = URI.parse(next_url)

        assert %{"cursor" => _cursor, "direction" => "forward", "limit" => "2"} =
                 URI.decode_query(query)
      end
    end

    test "when it has int contract calls internally", %{conn: conn} do
      contract_pk = TS.address(0)
      contract = Enc.encode(:contract_pubkey, contract_pk)
      account_pk = TS.address(1)
      account_id = :aeser_id.create(:account, account_pk)
      height = 398
      mbi = 2
      create_txi = 432

      {:ok, aetx} =
        :aec_spend_tx.new(%{
          sender_id: account_id,
          recipient_id: account_id,
          amount: 2,
          fee: 3,
          nonce: 4,
          payload: ""
        })

      {:spend_tx, tx} = :aetx.specialize_type(aetx)

      store =
        empty_store()
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
        )
        |> Store.put(
          Model.GrpIntContractCall,
          Model.grp_int_contract_call(index: {create_txi, 1, 0})
        )
        |> Store.put(Model.IntContractCall, Model.int_contract_call(index: {1, 0}))
        |> Store.put(
          Model.GrpIntContractCall,
          Model.grp_int_contract_call(index: {create_txi, 1, 1})
        )
        |> Store.put(Model.IntContractCall, Model.int_contract_call(index: {1, 1}))
        |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {height, mbi}, id: "hash1"))
        |> Store.put(
          Model.GrpIntContractCall,
          Model.grp_int_contract_call(index: {create_txi, 2, 0})
        )
        |> Store.put(Model.IntContractCall, Model.int_contract_call(index: {2, 0}))
        |> Store.put(
          Model.GrpIntContractCall,
          Model.grp_int_contract_call(index: {create_txi, 2, 1})
        )
        |> Store.put(Model.IntContractCall, Model.int_contract_call(index: {2, 1}))
        |> Store.put(Model.Tx, Model.tx(index: 2, block_index: {height, mbi}, id: "hash2"))

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             "hash1" ->
               {"", :spend_tx, aetx, tx}

             "hash2" ->
               {"", :spend_tx, aetx, tx}
           end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :header end]},
        {:aetx_sign, [], [serialize_for_client: fn :header, ^aetx -> %{} end]},
        {Format, [], [to_map: fn _state, _record, _tab -> %{} end]}
      ] do
        assert %{"prev" => nil, "data" => [tx1, tx2], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/accounts/#{contract}/activities", direction: "forward", limit: 2)
                 |> json_response(200)

        assert %{
                 "height" => ^height,
                 "type" => "InternalContractCallEvent"
               } = tx1

        assert %{
                 "height" => ^height,
                 "type" => "InternalContractCallEvent"
               } = tx2

        assert %URI{query: query} = URI.parse(next_url)

        assert %{"cursor" => _cursor, "direction" => "forward", "limit" => "2"} =
                 URI.decode_query(query)
      end
    end

    test "when it has int contract calls externally", %{conn: conn} do
      contract_pk = TS.address(0)
      contract = Enc.encode(:contract_pubkey, contract_pk)
      account_pk = TS.address(1)
      account_id = :aeser_id.create(:account, account_pk)
      height = 398
      mbi = 2

      {:ok, aetx} =
        :aec_spend_tx.new(%{
          sender_id: account_id,
          recipient_id: account_id,
          amount: 2,
          fee: 3,
          nonce: 4,
          payload: ""
        })

      {:spend_tx, tx} = :aetx.specialize_type(aetx)

      store =
        empty_store()
        |> Store.put(
          Model.IdIntContractCall,
          Model.id_int_contract_call(index: {contract_pk, 1, 1, 0})
        )
        |> Store.put(Model.IntContractCall, Model.int_contract_call(index: {1, 0}))
        |> Store.put(
          Model.IdIntContractCall,
          Model.id_int_contract_call(index: {contract_pk, 1, 1, 1})
        )
        |> Store.put(Model.IntContractCall, Model.int_contract_call(index: {1, 1}))
        |> Store.put(Model.Tx, Model.tx(index: 1, block_index: {height, mbi}, id: "hash1"))
        |> Store.put(
          Model.IdIntContractCall,
          Model.id_int_contract_call(index: {contract_pk, 3, 2, 0})
        )
        |> Store.put(Model.IntContractCall, Model.int_contract_call(index: {2, 0}))
        |> Store.put(
          Model.IdIntContractCall,
          Model.id_int_contract_call(index: {contract_pk, 1, 2, 1})
        )
        |> Store.put(Model.IntContractCall, Model.int_contract_call(index: {2, 1}))
        |> Store.put(Model.Tx, Model.tx(index: 2, block_index: {height, mbi}, id: "hash2"))

      with_mocks [
        {Db, [],
         [
           get_tx_data: fn
             "hash1" ->
               {"", :spend_tx, aetx, tx}

             "hash2" ->
               {"", :spend_tx, aetx, tx}
           end
         ]},
        {:aec_db, [], [get_header: fn _block_hash -> :header end]},
        {:aetx_sign, [], [serialize_for_client: fn :header, ^aetx -> %{} end]},
        {Format, [], [to_map: fn _state, _record, _tab -> %{} end]}
      ] do
        assert %{"prev" => nil, "data" => [tx1, tx2], "next" => next_url} =
                 conn
                 |> with_store(store)
                 |> get("/v2/accounts/#{contract}/activities", direction: "forward", limit: 2)
                 |> json_response(200)

        assert %{
                 "height" => ^height,
                 "type" => "InternalContractCallEvent"
               } = tx1

        assert %{
                 "height" => ^height,
                 "type" => "InternalContractCallEvent"
               } = tx2

        assert %URI{query: query} = URI.parse(next_url)

        assert %{"cursor" => _cursor, "direction" => "forward", "limit" => "2"} =
                 URI.decode_query(query)
      end
    end

    test "when it has int transfers from oracle rewards or name fees", %{conn: conn} do
      account_pk = TS.address(0)
      account = Enc.encode(:account_pubkey, account_pk)
      height = 398
      [txi1, txi2, txi3] = [123, 456, 789]

      store =
        empty_store()
        |> Store.put(
          Model.TargetKindIntTransferTx,
          Model.target_kind_int_transfer_tx(
            index: {account_pk, "reward_oracle", {height, txi1}, txi1}
          )
        )
        |> Store.put(
          Model.IntTransferTx,
          Model.int_transfer_tx(
            index: {{height, txi1}, "reward_oracle", account_pk, txi1},
            amount: 10
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: txi1, block_index: {height, 0}, id: "hash1"))
        |> Store.put(
          Model.TargetKindIntTransferTx,
          Model.target_kind_int_transfer_tx(
            index: {account_pk, "fee_lock_name", {height, txi2}, txi2}
          )
        )
        |> Store.put(
          Model.IntTransferTx,
          Model.int_transfer_tx(
            index: {{height, txi2}, "fee_lock_name", account_pk, txi2},
            amount: 20
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: txi2, block_index: {height, 1}, id: "hash2"))
        |> Store.put(
          Model.TargetKindIntTransferTx,
          Model.target_kind_int_transfer_tx(
            index: {account_pk, "fee_lock_name", {height, txi3}, txi3}
          )
        )
        |> Store.put(
          Model.IntTransferTx,
          Model.int_transfer_tx(
            index: {{height, txi3}, "fee_lock_name", account_pk, txi3},
            amount: 30
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: txi3, block_index: {height, 1}, id: "hash3"))

      assert %{"prev" => nil, "data" => [activity1, activity2] = data, "next" => next_url} =
               conn
               |> with_store(store)
               |> get("/v2/accounts/#{account}/activities", direction: "forward", limit: 2)
               |> json_response(200)

      assert %{
               "height" => ^height,
               "type" => "InternalTransferEvent",
               "payload" => %{
                 "kind" => "reward_oracle",
                 "amount" => 10
               }
             } = activity1

      assert %{
               "height" => ^height,
               "type" => "InternalTransferEvent",
               "payload" => %{
                 "kind" => "fee_lock_name",
                 "amount" => 20
               }
             } = activity2

      assert %{"prev" => prev_url, "data" => [activity3], "next" => nil} =
               conn
               |> with_store(store)
               |> get(next_url)
               |> json_response(200)

      assert %{"height" => 398, "type" => "InternalTransferEvent", "payload" => %{"amount" => 30}} =
               activity3

      assert %{"data" => ^data} = conn |> with_store(store) |> get(prev_url) |> json_response(200)
    end

    test "when it has both gen-based and tx-based int transfers", %{conn: conn} do
      account_pk = TS.address(0)
      account = Enc.encode(:account_pubkey, account_pk)
      height = 398
      [txi1, txi2, txi3] = [123, 456, 789]

      store =
        empty_store()
        |> Store.put(
          Model.TargetKindIntTransferTx,
          Model.target_kind_int_transfer_tx(
            index: {account_pk, "reward_oracle", {height, txi1}, txi1}
          )
        )
        |> Store.put(
          Model.IntTransferTx,
          Model.int_transfer_tx(
            index: {{height, txi1}, "reward_oracle", account_pk, txi1},
            amount: 10
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: txi1, block_index: {height, 0}, id: "hash1"))
        |> Store.put(
          Model.TargetKindIntTransferTx,
          Model.target_kind_int_transfer_tx(
            index: {account_pk, "fee_lock_name", {height, txi2}, txi2}
          )
        )
        |> Store.put(
          Model.IntTransferTx,
          Model.int_transfer_tx(
            index: {{height, txi2}, "fee_lock_name", account_pk, txi2},
            amount: 20
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: txi2, block_index: {height, 1}, id: "hash2"))
        |> Store.put(
          Model.TargetKindIntTransferTx,
          Model.target_kind_int_transfer_tx(
            index: {account_pk, "reward_dev", {height + 1, -1}, -1}
          )
        )
        |> Store.put(
          Model.IntTransferTx,
          Model.int_transfer_tx(
            index: {{height + 1, -1}, "reward_dev", account_pk, -1},
            amount: 30
          )
        )
        |> Store.put(
          Model.TargetKindIntTransferTx,
          Model.target_kind_int_transfer_tx(
            index: {account_pk, "fee_lock_name", {height + 2, txi3}, txi3}
          )
        )
        |> Store.put(
          Model.IntTransferTx,
          Model.int_transfer_tx(
            index: {{height + 2, txi3}, "fee_lock_name", account_pk, txi3},
            amount: 40
          )
        )
        |> Store.put(Model.Tx, Model.tx(index: txi3, block_index: {height + 2, 0}, id: "hash3"))

      assert %{
               "prev" => nil,
               "data" => [activity1, activity2, activity3] = data,
               "next" => next_url
             } =
               conn
               |> with_store(store)
               |> get("/v2/accounts/#{account}/activities", direction: "forward", limit: 3)
               |> json_response(200)

      assert %{
               "height" => ^height,
               "type" => "InternalTransferEvent",
               "payload" => %{
                 "kind" => "reward_oracle",
                 "amount" => 10
               }
             } = activity1

      assert %{
               "height" => ^height,
               "type" => "InternalTransferEvent",
               "payload" => %{
                 "kind" => "fee_lock_name",
                 "amount" => 20
               }
             } = activity2

      assert %{
               "height" => 399,
               "type" => "InternalTransferEvent",
               "payload" => %{
                 "kind" => "reward_dev",
                 "amount" => 30
               }
             } = activity3

      assert %{"prev" => prev_url, "data" => [activity4], "next" => nil} =
               conn
               |> with_store(store)
               |> get(next_url)
               |> json_response(200)

      assert %{
               "height" => 400,
               "type" => "InternalTransferEvent",
               "payload" => %{"kind" => "fee_lock_name", "amount" => 40}
             } = activity4

      assert %{"data" => ^data} = conn |> with_store(store) |> get(prev_url) |> json_response(200)
    end

    test "when activities contain aexn tokens, it returns them as AexnEvent", %{conn: conn} do
      account_pk = TS.address(0)
      account = Enc.encode(:account_pubkey, account_pk)
      another_account_pk = TS.address(1)
      another_account = Enc.encode(:account_pubkey, another_account_pk)
      height1 = 398
      height2 = 399
      txi1 = 123
      txi2 = 456
      txi3 = 789

      store =
        empty_store()
        |> Store.put(
          Model.AexnTransfer,
          Model.aexn_transfer(index: {:aex9, account_pk, txi1, another_account_pk, 1, 1})
        )
        |> Store.put(Model.Tx, Model.tx(index: txi1, block_index: {height1, 0}, id: "hash1"))
        |> Store.put(
          Model.RevAexnTransfer,
          Model.aexn_transfer(index: {:aex141, account_pk, txi2, another_account_pk, 2, 2})
        )
        |> Store.put(Model.Tx, Model.tx(index: txi2, block_index: {height2, 0}, id: "hash2"))
        |> Store.put(
          Model.RevAexnTransfer,
          Model.aexn_transfer(index: {:aex9, account_pk, txi3, another_account_pk, 3, 3})
        )
        |> Store.put(Model.Tx, Model.tx(index: txi3, block_index: {height2, 0}, id: "hash3"))

      assert %{"prev" => nil, "data" => [activity1, activity2], "next" => next_url} =
               conn
               |> with_store(store)
               |> get("/v2/accounts/#{account}/activities", direction: "forward", limit: 2)
               |> json_response(200)

      assert %{
               "height" => ^height1,
               "type" => "Aex9TransferEvent",
               "payload" => %{
                 "from" => ^account,
                 "to" => ^another_account,
                 "value" => 1,
                 "log_index" => 1
               }
             } = activity1

      assert %{
               "height" => ^height2,
               "type" => "Aex141TransferEvent",
               "payload" => %{
                 "from" => ^another_account,
                 "to" => ^account,
                 "value" => 2,
                 "log_index" => 2
               }
             } = activity2

      assert %URI{query: query} = URI.parse(next_url)

      assert %{"cursor" => _cursor, "direction" => "forward", "limit" => "2"} =
               URI.decode_query(query)
    end

    test "when backwards and when activities contain aexn tokens, it returns them as AexnEvent",
         %{conn: conn} do
      account_pk = TS.address(0)
      account = Enc.encode(:account_pubkey, account_pk)
      another_account_pk = TS.address(1)
      another_account = Enc.encode(:account_pubkey, another_account_pk)
      height1 = 398
      height2 = 399
      txi1 = 123
      txi2 = 456
      txi3 = 789

      store =
        empty_store()
        |> Store.put(
          Model.AexnTransfer,
          Model.aexn_transfer(index: {:aex9, account_pk, txi1, another_account_pk, 1, 1})
        )
        |> Store.put(Model.Tx, Model.tx(index: txi1, block_index: {height1, 0}, id: "hash1"))
        |> Store.put(
          Model.RevAexnTransfer,
          Model.aexn_transfer(index: {:aex141, account_pk, txi2, another_account_pk, 2, 2})
        )
        |> Store.put(Model.Tx, Model.tx(index: txi2, block_index: {height2, 0}, id: "hash2"))
        |> Store.put(
          Model.RevAexnTransfer,
          Model.aexn_transfer(index: {:aex9, account_pk, txi3, another_account_pk, 3, 3})
        )
        |> Store.put(Model.Tx, Model.tx(index: txi3, block_index: {height2, 0}, id: "hash3"))

      assert %{"prev" => nil, "data" => [activity1, activity2], "next" => next_url} =
               conn
               |> with_store(store)
               |> get("/v2/accounts/#{account}/activities", limit: 2)
               |> json_response(200)

      assert %{
               "height" => ^height2,
               "type" => "Aex9TransferEvent",
               "payload" => %{
                 "from" => ^another_account,
                 "to" => ^account,
                 "value" => 3,
                 "log_index" => 3
               }
             } = activity1

      assert %{
               "height" => ^height2,
               "type" => "Aex141TransferEvent",
               "payload" => %{
                 "from" => ^another_account,
                 "to" => ^account,
                 "value" => 2,
                 "log_index" => 2
               }
             } = activity2

      assert %{"prev" => prev_url, "data" => [activity3], "next" => nil} =
               conn
               |> with_store(store)
               |> get(next_url)
               |> json_response(200)

      assert %{
               "height" => ^height1,
               "type" => "Aex9TransferEvent",
               "payload" => %{
                 "from" => ^account,
                 "to" => ^another_account,
                 "value" => 1,
                 "log_index" => 1
               }
             } = activity3

      refute is_nil(prev_url)
    end

    test "when the account is invalid, it returns an error", %{conn: conn} do
      invalid_account = "ak_foo"
      error_msg = "invalid id: #{invalid_account}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/accounts/#{invalid_account}/activities")
               |> json_response(400)
    end

    test "when cursor is invalid, it returns an error", %{conn: conn} do
      account_pk = TS.address(0)
      account = Enc.encode(:account_pubkey, account_pk)
      invalid_cursor = "1290318-aa-bb"
      error_msg = "invalid cursor: #{invalid_cursor}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/accounts/#{account}/activities", cursor: invalid_cursor)
               |> json_response(400)
    end

    test "when scoping by txi, it returns an error", %{conn: conn} do
      account_pk = TS.address(0)
      account = Enc.encode(:account_pubkey, account_pk)
      error_msg = "invalid scope: txi"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/accounts/#{account}/activities", scope: "txi:1-2")
               |> json_response(400)
    end
  end

  defp empty_store, do: NullStore.new() |> MemStore.new()
end
