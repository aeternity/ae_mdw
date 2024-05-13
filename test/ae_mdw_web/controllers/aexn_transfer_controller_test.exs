defmodule AeMdwWeb.AexnTransferControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.Origin

  require Model

  setup_all _context do
    :persistent_term.put({Origin, :hardforks_contracts}, [])
    :ok
  end

  @aex141_pk1 :crypto.strong_rand_bytes(32)
  @aex141_pk2 :crypto.strong_rand_bytes(32)
  @aex9_pk1 :crypto.strong_rand_bytes(32)
  @aex9_pk2 :crypto.strong_rand_bytes(32)
  @aex9_pk3 :crypto.strong_rand_bytes(32)
  @contracts [
    encode_contract(@aex141_pk1),
    encode_contract(@aex141_pk2),
    encode_contract(@aex9_pk1),
    encode_contract(@aex9_pk2),
    encode_contract(@aex9_pk3)
  ]

  @account_pk :crypto.strong_rand_bytes(32)
  @from_pk1 :crypto.strong_rand_bytes(32)
  @from_pk2 :crypto.strong_rand_bytes(32)
  @to_pk1 :crypto.strong_rand_bytes(32)
  @to_pk2 :crypto.strong_rand_bytes(32)
  @senders [encode_account(@from_pk1), encode_account(@from_pk2), encode_account(@account_pk)]
  @recipients [encode_account(@to_pk1), encode_account(@to_pk2), encode_account(@account_pk)]

  @default_limit 10
  @aexn_type_sample 1_000
  @log_index_range 0..(2 * @aexn_type_sample)
  @aex9_amount_range 1_000_000_000..9_999_999_999
  @aex141_token_range 1_000..9_999
  @txi_range 10_000_000..99_999_999

  setup_all do
    store =
      :aex9
      |> List.duplicate(@aexn_type_sample)
      |> Kernel.++(List.duplicate(:aex141, @aexn_type_sample))
      |> Enum.with_index()
      |> Enum.reduce(empty_store(), fn {aexn_type, i}, store ->
        {from_pk, to_pk, contract_pk} =
          cond do
            i <= 20 or (i > @aexn_type_sample and i <= @aexn_type_sample + 20) ->
              if aexn_type == :aex141 do
                {@from_pk1, @to_pk1, @aex141_pk1}
              else
                {@from_pk1, @to_pk1, @aex9_pk1}
              end

            i <= 40 or (i > @aexn_type_sample and i <= @aexn_type_sample + 40) ->
              if aexn_type == :aex141 do
                {@from_pk1, @to_pk2, @aex141_pk2}
              else
                {@from_pk1, @to_pk2, @aex9_pk2}
              end

            i <= 60 or (i > @aexn_type_sample and i <= @aexn_type_sample + 60) ->
              if aexn_type == :aex141 do
                {@from_pk2, @to_pk1, @aex141_pk1}
              else
                {@from_pk2, @to_pk1, @aex9_pk1}
              end

            i <= 80 or (i > @aexn_type_sample and i <= @aexn_type_sample + 80) ->
              if aexn_type == :aex141 do
                {@from_pk2, @to_pk2, @aex141_pk2}
              else
                {@from_pk2, @to_pk2, @aex9_pk2}
              end

            i <= 100 or (i > @aexn_type_sample and i <= @aexn_type_sample + 100) ->
              if aexn_type == :aex141 do
                {@from_pk1, @to_pk1, @aex141_pk1}
              else
                {@account_pk, @to_pk1, @aex9_pk3}
              end

            i <= 120 or (i > @aexn_type_sample and i <= @aexn_type_sample + 120) ->
              if aexn_type == :aex141 do
                {@from_pk1, @to_pk1, @aex141_pk1}
              else
                {@from_pk1, @account_pk, @aex9_pk3}
              end

            true ->
              {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32),
               :crypto.strong_rand_bytes(32)}
          end

        create_txi =
          case contract_pk do
            @aex141_pk1 -> 10_000_001
            @aex9_pk1 -> 10_000_002
            @aex141_pk2 -> 10_000_003
            @aex9_pk2 -> 10_000_004
            @aex9_pk3 -> 10_000_005
            _other -> 10_000_006
          end

        txi = 10_000_100 + i

        value =
          if aexn_type == :aex9,
            do: Enum.random(@aex9_amount_range),
            else: Enum.random(@aex141_token_range)

        m_transfer =
          Model.aexn_transfer(
            index: {aexn_type, from_pk, txi, to_pk, value, i},
            contract_pk: contract_pk
          )

        m_rev_transfer =
          Model.rev_aexn_transfer(index: {aexn_type, to_pk, txi, from_pk, value, i})

        m_pair_transfer =
          Model.aexn_pair_transfer(index: {aexn_type, from_pk, to_pk, txi, value, i})

        m_ct_from =
          Model.aexn_contract_from_transfer(index: {create_txi, from_pk, txi, to_pk, value, i})

        m_ct_to =
          Model.aexn_contract_to_transfer(index: {create_txi, to_pk, txi, from_pk, value, i})

        store
        |> Store.put(
          Model.Tx,
          Model.tx(index: txi, id: <<txi::256>>, block_index: {i, 0})
        )
        |> Store.put(Model.AexnTransfer, m_transfer)
        |> Store.put(Model.RevAexnTransfer, m_rev_transfer)
        |> Store.put(Model.AexnPairTransfer, m_pair_transfer)
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
        )
        |> Store.put(Model.AexnContractFromTransfer, m_ct_from)
        |> Store.put(Model.AexnContractToTransfer, m_ct_to)
        |> Store.put(Model.AexnContract, Model.aexn_contract(index: {aexn_type, contract_pk}))
      end)

    [store: store]
  end

  describe "aex9_transfers_from" do
    test "gets aex9 transfers sorted by desc txi", %{conn: conn, store: store} do
      sender_id = encode_account(@from_pk1)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/from/#{sender_id}")
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)

      assert ^aex9_transfers =
               Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert Enum.all?(aex9_transfers, &aex9_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") <=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex9_transfers, &aex9_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "gets aex9 transfers sorted by asc txi", %{conn: conn, store: store} do
      sender_id = encode_account(@from_pk2)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/from/#{sender_id}", direction: "forward")
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = aex9_transfers |> Enum.sort_by(&Map.fetch!(&1, "block_height"))
      assert Enum.all?(aex9_transfers, &aex9_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex9_transfers, &aex9_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn} do
      account_id_without_transfer = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> get("/v2/aex9/transfers/from/#{account_id_without_transfer}")
               |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex9/transfers/from/#{invalid_id}") |> json_response(400)
    end
  end

  describe "aex9_transfers_to" do
    test "gets aex9 transfers sorted by desc txi", %{conn: conn, store: store} do
      recipient_id = encode_account(@to_pk1)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/to/#{recipient_id}")
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)

      assert ^aex9_transfers =
               Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert Enum.all?(aex9_transfers, &aex9_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") <=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex9_transfers, &aex9_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "gets aex9 transfers sorted by asc txi", %{conn: conn, store: store} do
      recipient_id = encode_account(@to_pk2)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/to/#{recipient_id}", direction: "forward")
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"))
      assert Enum.all?(aex9_transfers, &aex9_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex9_transfers, &aex9_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn} do
      account_id_without_transfer = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> get("/v2/aex9/transfers/to/#{account_id_without_transfer}")
               |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex9/transfers/to/#{invalid_id}") |> json_response(400)
    end
  end

  describe "aex9_transfers_from_to" do
    test "gets aex9 transfers sorted by desc txi", %{conn: conn, store: store} do
      sender_id = encode_account(@from_pk1)
      recipient_id = encode_account(@to_pk2)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/from-to/#{sender_id}/#{recipient_id}")
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)

      assert ^aex9_transfers =
               Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert Enum.all?(aex9_transfers, &aex9_valid_pair_transfer?(sender_id, recipient_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") <=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(
               next_aex9_transfers,
               &aex9_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "gets aex9 transfers sorted by asc txi", %{conn: conn, store: store} do
      sender_id = encode_account(@from_pk2)
      recipient_id = encode_account(@to_pk1)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/from-to/#{sender_id}/#{recipient_id}",
                 direction: "forward"
               )
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"))
      assert Enum.all?(aex9_transfers, &aex9_valid_pair_transfer?(sender_id, recipient_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(
               next_aex9_transfers,
               &aex9_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn} do
      account_id_without_transfer = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> get(
                 "/v2/aex9/transfers/from-to/#{account_id_without_transfer}/#{encode_account(@to_pk1)}"
               )
               |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex9/transfers/from-to/#{invalid_id}/#{encode_account(@to_pk1)}")
               |> json_response(400)
    end
  end

  describe "aex9_contract_transfers" do
    test "gets transfers sorted by desc txi", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex9_pk3)
      account_id = encode_account(@account_pk)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex9/#{contract_id}/transfers", account: account_id)
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)

      assert ^aex9_transfers =
               Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert Enum.all?(
               aex9_transfers,
               &aex9_valid_account_transfer?(account_id, &1, contract_id)
             )

      assert %{"data" => next_aex9_transfers, "prev" => prev} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") <=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(
               next_aex9_transfers,
               &aex9_valid_account_transfer?(account_id, &1, contract_id)
             )

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev) |> json_response(200)
    end

    test "gets transfers sorted by asc txi", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex9_pk3)
      account_id = encode_account(@account_pk)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex9/#{contract_id}/transfers",
                 direction: "forward",
                 account: account_id
               )
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"))
      assert Enum.all?(aex9_transfers, &aex9_valid_account_transfer?(account_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex9_transfers, &aex9_valid_account_transfer?(account_id, &1))

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex9_pk1)
      account_id_without_transfer = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v3/aex9/#{contract_id}/transfers", account: account_id_without_transfer)
               |> json_response(200)
    end

    test "returns bad request when sender id is invalid", %{conn: conn} do
      invalid_id = "ct_InvalidId"
      error_msg = "invalid id: #{invalid_id}"
      account_id = encode_account(@from_pk1)

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/aex9/#{invalid_id}/transfers", account: account_id)
               |> json_response(400)
    end

    test "returns bad request when both sender and recipient params are used", %{conn: conn} do
      contract_id = encode_contract(@aex9_pk1)
      account_id1 = encode_account(@from_pk1)
      account_id2 = encode_account(@from_pk2)
      error_msg = "invalid query: set either a recipient or a sender"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/aex9/#{contract_id}/transfers",
                 sender: account_id1,
                 recipient: account_id2
               )
               |> json_response(400)
    end
  end

  describe "sender aex9_contract_transfers" do
    test "gets transfers sorted by desc txi", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex9_pk1)
      sender_id = encode_account(@from_pk1)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex9/#{contract_id}/transfers", sender: sender_id)
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)

      assert ^aex9_transfers =
               Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert Enum.all?(
               aex9_transfers,
               &aex9_valid_sender_transfer?(sender_id, &1, contract_id)
             )

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") <=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(
               next_aex9_transfers,
               &aex9_valid_sender_transfer?(sender_id, &1, contract_id)
             )

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "gets transfers sorted by asc txi", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex9_pk1)
      sender_id = encode_account(@from_pk2)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex9/#{contract_id}/transfers",
                 direction: "forward",
                 sender: sender_id
               )
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"))
      assert Enum.all?(aex9_transfers, &aex9_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex9_transfers, &aex9_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex9_pk1)
      account_id_without_transfer = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v3/aex9/#{contract_id}/transfers", sender: account_id_without_transfer)
               |> json_response(200)
    end

    test "returns bad request when sender id is invalid", %{conn: conn} do
      invalid_id = "ct_InvalidId"
      error_msg = "invalid id: #{invalid_id}"
      account_id = encode_account(@from_pk1)

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/aex9/#{invalid_id}/transfers", sender: account_id)
               |> json_response(400)
    end

    test "returns bad request when both sender and recipient params are used", %{conn: conn} do
      contract_id = encode_contract(@aex9_pk1)
      account_id1 = encode_account(@from_pk1)
      account_id2 = encode_account(@from_pk2)
      error_msg = "invalid query: set either a recipient or a sender"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/aex9/#{contract_id}/transfers",
                 sender: account_id1,
                 recipient: account_id2
               )
               |> json_response(400)
    end
  end

  describe "recipient aex9_contract_transfers" do
    test "gets aex9 transfers sorted by desc txi", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex9_pk1)
      recipient_id = encode_account(@to_pk1)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex9/#{contract_id}/transfers", recipient: recipient_id)
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)

      assert ^aex9_transfers =
               Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert Enum.all?(
               aex9_transfers,
               &aex9_valid_recipient_transfer?(recipient_id, &1, contract_id)
             )

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") <=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(
               next_aex9_transfers,
               &aex9_valid_recipient_transfer?(recipient_id, &1, contract_id)
             )

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "gets aex9 transfers sorted by asc txi", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex9_pk1)
      recipient_id = encode_account(@to_pk1)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex9/#{contract_id}/transfers",
                 direction: "forward",
                 recipient: recipient_id
               )
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, &Map.fetch!(&1, "block_height"))

      assert Enum.all?(
               aex9_transfers,
               &aex9_valid_recipient_transfer?(recipient_id, &1, contract_id)
             )

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)

      assert ^next_aex9_transfers =
               Enum.sort_by(next_aex9_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex9_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex9_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(
               next_aex9_transfers,
               &aex9_valid_recipient_transfer?(recipient_id, &1, contract_id)
             )

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex9_pk1)
      account_id_without_transfer = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v3/aex9/#{contract_id}/transfers", recipient: account_id_without_transfer)
               |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ct_InvalidId"
      error_msg = "invalid id: #{invalid_id}"
      account_id = encode_account(@from_pk1)

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/aex9/#{invalid_id}/transfers", recipient: account_id)
               |> json_response(400)
    end
  end

  describe "aex141_transfers_from" do
    test "gets aex141 transfers sorted by desc txi", %{conn: conn, store: store} do
      sender_id = encode_account(@from_pk1)
      contract_id = encode_contract(@aex141_pk1)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/#{contract_id}/transfers?from=#{sender_id}")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)

      assert ^aex141_transfers =
               Enum.sort_by(aex141_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert Enum.all?(aex141_transfers, &aex141_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)

      assert ^next_aex141_transfers =
               Enum.sort_by(next_aex141_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert next_aex141_transfers |> List.first() |> Map.fetch!("block_height") <=
               aex141_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex141_transfers, &aex141_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "gets aex141 transfers sorted by asc txi", %{conn: conn, store: store} do
      sender_id = encode_account(@from_pk2)
      contract_id = encode_contract(@aex141_pk1)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/#{contract_id}/transfers?from=#{sender_id}",
                 direction: "forward"
               )
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, &Map.fetch!(&1, "block_height"))
      assert Enum.all?(aex141_transfers, &aex141_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)

      assert ^next_aex141_transfers =
               Enum.sort_by(next_aex141_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex141_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex141_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex141_transfers, &aex141_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "gets some aex141 transfers sorted by asc txi filtered by contract", %{
      conn: conn,
      store: store
    } do
      sender_id = encode_account(@from_pk2)
      contract_id = encode_contract(@aex141_pk1)
      limit = 3

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/#{contract_id}/transfers?from=#{sender_id}",
                 direction: "forward",
                 limit: limit
               )
               |> json_response(200)

      assert length(aex141_transfers) == 3
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, &Map.fetch!(&1, "block_height"))

      assert Enum.all?(
               aex141_transfers,
               &aex141_valid_sender_transfer?(sender_id, &1, [contract_id])
             )

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert length(next_aex141_transfers) == 3

      assert ^next_aex141_transfers =
               Enum.sort_by(next_aex141_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex141_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex141_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(
               next_aex141_transfers,
               &aex141_valid_sender_transfer?(sender_id, &1, [contract_id])
             )

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"
      contract_id = encode_contract(@aex141_pk1)

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/aex141/#{contract_id}/transfers?from=#{invalid_id}")
               |> json_response(400)
    end
  end

  describe "aex141_transfers_to" do
    test "gets aex141 transfers sorted by desc txi", %{conn: conn, store: store} do
      recipient_id = encode_account(@to_pk1)
      contract_id = encode_contract(@aex141_pk1)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/#{contract_id}/transfers?to=#{recipient_id}")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)

      assert ^aex141_transfers =
               Enum.sort_by(aex141_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert Enum.all?(aex141_transfers, &aex141_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)

      assert ^next_aex141_transfers =
               Enum.sort_by(next_aex141_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert next_aex141_transfers |> List.first() |> Map.fetch!("block_height") <=
               aex141_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex141_transfers, &aex141_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "gets aex141 transfers sorted by asc txi", %{conn: conn, store: store} do
      recipient_id = encode_account(@to_pk2)
      contract_id = encode_contract(@aex141_pk2)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/#{contract_id}/transfers?to=#{recipient_id}",
                 direction: "forward"
               )
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, &Map.fetch!(&1, "block_height"))
      assert Enum.all?(aex141_transfers, &aex141_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)

      assert ^next_aex141_transfers =
               Enum.sort_by(next_aex141_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex141_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex141_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex141_transfers, &aex141_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "gets some aex141 transfers sorted by asc txi filtered by contract", %{
      conn: conn,
      store: store
    } do
      recipient_id = encode_account(@to_pk2)
      contract_id = encode_contract(@aex141_pk2)
      limit = 3

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/#{contract_id}/transfers?to=#{recipient_id}",
                 direction: "forward",
                 limit: limit
               )
               |> json_response(200)

      assert length(aex141_transfers) == limit
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, &Map.fetch!(&1, "block_height"))

      assert Enum.all?(
               aex141_transfers,
               &aex141_valid_recipient_transfer?(recipient_id, &1, [contract_id])
             )

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert length(next_aex141_transfers) == 3

      assert ^next_aex141_transfers =
               Enum.sort_by(next_aex141_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex141_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex141_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(
               next_aex141_transfers,
               &aex141_valid_recipient_transfer?(recipient_id, &1, [contract_id])
             )

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"
      contract_id = encode_contract(@aex141_pk1)

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/aex141/#{contract_id}/transfers?to=#{invalid_id}")
               |> json_response(400)
    end
  end

  describe "aex141_transfers_from_to" do
    test "gets aex141 transfers sorted by desc txi", %{conn: conn, store: store} do
      sender_id = encode_account(@from_pk1)
      recipient_id = encode_account(@to_pk2)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/transfers", from: sender_id, to: recipient_id)
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)

      assert ^aex141_transfers =
               Enum.sort_by(aex141_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert Enum.all?(
               aex141_transfers,
               &aex141_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)

      assert ^next_aex141_transfers =
               Enum.sort_by(next_aex141_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert next_aex141_transfers |> List.first() |> Map.fetch!("block_height") <=
               aex141_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(
               next_aex141_transfers,
               &aex141_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "gets aex141 transfers sorted by asc txi", %{conn: conn, store: store} do
      sender_id = encode_account(@from_pk2)
      recipient_id = encode_account(@to_pk1)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/transfers",
                 from: sender_id,
                 to: recipient_id,
                 direction: "forward"
               )
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, &Map.fetch!(&1, "block_height"))

      assert Enum.all?(
               aex141_transfers,
               &aex141_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)

      assert ^next_aex141_transfers =
               Enum.sort_by(next_aex141_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex141_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex141_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(
               next_aex141_transfers,
               &aex141_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn} do
      account_id_without_transfer = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> get(
                 "/v3/aex141/transfers",
                 from: account_id_without_transfer,
                 to: encode_account(@to_pk1)
               )
               |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/aex141/transfers",
                 from: invalid_id,
                 to: encode_account(@to_pk1)
               )
               |> json_response(400)
    end
  end

  describe "aex141_transfers" do
    test "gets aex141 transfers sorted by desc txi", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex141_pk1)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/#{contract_id}/transfers")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)

      assert ^aex141_transfers =
               Enum.sort_by(aex141_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert Enum.all?(aex141_transfers, &aex141_valid_contract_transfer?(contract_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)

      assert ^next_aex141_transfers =
               Enum.sort_by(next_aex141_transfers, &Map.fetch!(&1, "block_height"), :desc)

      assert next_aex141_transfers |> List.first() |> Map.fetch!("block_height") <=
               aex141_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex141_transfers, &aex141_valid_contract_transfer?(contract_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "gets aex141 transfers sorted by asc txi", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex141_pk2)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/#{contract_id}/transfers", direction: "forward")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, &Map.fetch!(&1, "block_height"))
      assert Enum.all?(aex141_transfers, &aex141_valid_contract_transfer?(contract_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)

      assert ^next_aex141_transfers =
               Enum.sort_by(next_aex141_transfers, &Map.fetch!(&1, "block_height"))

      assert next_aex141_transfers |> List.first() |> Map.fetch!("block_height") >=
               aex141_transfers |> List.last() |> Map.fetch!("block_height")

      assert Enum.all?(next_aex141_transfers, &aex141_valid_contract_transfer?(contract_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "returns not found for unknown contract", %{conn: conn} do
      unknown_id = encode_contract(:crypto.strong_rand_bytes(32))
      error_message = "not found: #{unknown_id}"

      assert %{"error" => ^error_message} =
               conn |> get("/v3/aex141/#{unknown_id}/transfers") |> json_response(404)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ct_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v3/aex141/#{invalid_id}/transfers") |> json_response(400)
    end

    test "returns bad request when cursor is invalid", %{conn: conn, store: store} do
      contract_id = encode_contract(@aex141_pk2)
      invalid_cursor = "foo"
      error_msg = "invalid cursor: #{invalid_cursor}"

      assert %{"error" => ^error_msg} =
               conn
               |> with_store(store)
               |> get("/v3/aex141/#{contract_id}/transfers", cursor: invalid_cursor)
               |> json_response(400)
    end
  end

  defp aex9_valid_account_transfer?(
         account_id,
         %{
           "sender" => sender,
           "recipient" => recipient,
           "log_idx" => log_idx,
           "amount" => amount,
           "contract_id" => contract_id
         },
         req_contract_id \\ nil
       ) do
    valid_contract? =
      if req_contract_id do
        contract_id == req_contract_id
      else
        contract_id in @contracts
      end

    (account_id == sender or account_id == recipient) and
      log_idx in @log_index_range and amount in @aex9_amount_range and valid_contract?
  end

  defp aex9_valid_sender_transfer?(
         sender_id,
         %{
           "sender" => sender,
           "recipient" => recipient,
           "log_idx" => log_idx,
           "amount" => amount,
           "contract_id" => contract_id
         },
         req_contract_id \\ nil
       ) do
    valid_contract? =
      if req_contract_id do
        contract_id == req_contract_id
      else
        contract_id in @contracts
      end

    sender == sender_id and recipient in @recipients and
      log_idx in @log_index_range and amount in @aex9_amount_range and valid_contract?
  end

  defp aex9_valid_recipient_transfer?(
         recipient_id,
         %{
           "sender" => sender,
           "recipient" => recipient,
           "log_idx" => log_idx,
           "amount" => amount,
           "contract_id" => contract_id
         },
         req_contract_id \\ nil
       ) do
    valid_contract? =
      if req_contract_id do
        contract_id == req_contract_id
      else
        contract_id in @contracts
      end

    sender in @senders and recipient == recipient_id and
      log_idx in @log_index_range and amount in @aex9_amount_range and valid_contract?
  end

  defp aex9_valid_pair_transfer?(sender_id, recipient_id, %{
         "sender" => sender,
         "recipient" => recipient,
         "call_txi" => call_txi,
         "log_idx" => log_idx,
         "amount" => amount,
         "contract_id" => contract_id
       }) do
    sender == sender_id and recipient == recipient_id and call_txi in @txi_range and
      log_idx in @log_index_range and amount in @aex9_amount_range and contract_id in @contracts
  end

  defp aex141_valid_contract_transfer?(contract_id, %{
         "sender" => sender,
         "recipient" => recipient,
         "tx_hash" => call_tx_hash,
         "log_idx" => log_idx,
         "token_id" => token_id,
         "contract_id" => ct_id
       }) do
    call_txi = tx_hash_to_txi(call_tx_hash)

    sender in @senders and recipient in @recipients and call_txi in @txi_range and
      log_idx in @log_index_range and token_id in @aex141_token_range and
      contract_id == ct_id
  end

  defp aex141_valid_sender_transfer?(
         sender_id,
         %{
           "sender" => sender,
           "recipient" => recipient,
           "tx_hash" => tx_hash,
           "log_idx" => log_idx,
           "token_id" => token_id,
           "contract_id" => contract_id
         },
         contracts \\ @contracts
       ) do
    call_txi = tx_hash_to_txi(tx_hash)

    sender == sender_id and recipient in @recipients and call_txi in @txi_range and
      log_idx in @log_index_range and token_id in @aex141_token_range and
      contract_id in contracts
  end

  defp aex141_valid_recipient_transfer?(
         recipient_id,
         %{
           "sender" => sender,
           "recipient" => recipient,
           "tx_hash" => tx_hash,
           "log_idx" => log_idx,
           "token_id" => token_id,
           "contract_id" => contract_id
         },
         contracts \\ @contracts
       ) do
    call_txi = tx_hash_to_txi(tx_hash)

    sender in @senders and recipient == recipient_id and call_txi in @txi_range and
      log_idx in @log_index_range and token_id in @aex141_token_range and
      contract_id in contracts
  end

  defp aex141_valid_pair_transfer?(sender_id, recipient_id, %{
         "sender" => sender,
         "recipient" => recipient,
         "call_txi" => call_txi,
         "log_idx" => log_idx,
         "token_id" => token_id,
         "contract_id" => contract_id
       }) do
    sender == sender_id and recipient == recipient_id and call_txi in @txi_range and
      log_idx in @log_index_range and token_id in @aex141_token_range and
      contract_id in @contracts
  end

  defp tx_hash_to_txi(tx_hash) do
    <<txi::256>> =
      tx_hash
      |> Enc.decode()
      |> elem(1)

    txi
  end
end
