defmodule AeMdwWeb.ActivitiesControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  alias :aeser_api_encoder, as: Enc
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
        assert %{"prev" => nil, "data" => [tx3, tx2, tx1], "next" => next_url} =
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
  end

  defp empty_store, do: NullStore.new() |> MemStore.new()
end
