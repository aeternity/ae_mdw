defmodule AeMdwWeb.AexnTransferControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1, enc_id: 1]

  require Model

  @contract_pk1 :crypto.strong_rand_bytes(32)
  @contract_pk2 :crypto.strong_rand_bytes(32)
  @contracts [enc_ct(@contract_pk1), enc_ct(@contract_pk2)]

  @from_pk1 :crypto.strong_rand_bytes(32)
  @from_pk2 :crypto.strong_rand_bytes(32)
  @to_pk1 :crypto.strong_rand_bytes(32)
  @to_pk2 :crypto.strong_rand_bytes(32)
  @senders [enc_id(@from_pk1), enc_id(@from_pk2)]
  @recipients [enc_id(@to_pk1), enc_id(@to_pk2)]

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
      |> Enum.reduce(MemStore.new(NullStore.new()), fn {aexn_type, i}, store ->
        {from_pk, to_pk, contract_pk, create_txi} =
          cond do
            i <= 20 or (i > @aexn_type_sample and i <= @aexn_type_sample + 20) ->
              {@from_pk1, @to_pk1, @contract_pk1, 10_000_001}

            i <= 40 or (i > @aexn_type_sample and i <= @aexn_type_sample + 40) ->
              {@from_pk1, @to_pk2, @contract_pk2, 10_000_002}

            i <= 60 or (i > @aexn_type_sample and i <= @aexn_type_sample + 60) ->
              {@from_pk2, @to_pk1, @contract_pk1, 10_000_001}

            i <= 80 or (i > @aexn_type_sample and i <= @aexn_type_sample + 80) ->
              {@from_pk2, @to_pk2, @contract_pk2, 10_000_002}

            true ->
              {:crypto.strong_rand_bytes(32), :crypto.strong_rand_bytes(32),
               :crypto.strong_rand_bytes(32), 10_000_003}
          end

        txi = Enum.random(@txi_range)

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

        store =
          store
          |> Store.put(
            Model.Tx,
            Model.tx(index: txi, id: :crypto.strong_rand_bytes(32), block_index: {i, 0})
          )
          |> Store.put(Model.AexnTransfer, m_transfer)
          |> Store.put(Model.RevAexnTransfer, m_rev_transfer)
          |> Store.put(Model.AexnPairTransfer, m_pair_transfer)

        if aexn_type == :aex141 do
          m_ct_from =
            Model.aexn_contract_from_transfer(index: {create_txi, from_pk, txi, to_pk, value, i})

          m_ct_to =
            Model.aexn_contract_to_transfer(index: {create_txi, to_pk, txi, from_pk, value, i})

          store
          |> Store.put(
            Model.Field,
            Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
          )
          |> Store.put(Model.AexnContractFromTransfer, m_ct_from)
          |> Store.put(Model.AexnContractToTransfer, m_ct_to)
        else
          store
        end
      end)

    [store: store]
  end

  describe "aex9_transfers_from" do
    test "gets aex9 transfers sorted by desc txi", %{conn: conn, store: store} do
      sender_id = enc_id(@from_pk1)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/from/#{sender_id}")
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, & &1["call_txi"], :desc)
      assert Enum.all?(aex9_transfers, &aex9_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)
      assert ^next_aex9_transfers = Enum.sort_by(next_aex9_transfers, & &1["call_txi"], :desc)
      assert List.first(next_aex9_transfers)["call_txi"] <= List.last(aex9_transfers)["call_txi"]
      assert Enum.all?(next_aex9_transfers, &aex9_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "gets aex9 transfers sorted by asc txi", %{conn: conn, store: store} do
      sender_id = enc_id(@from_pk2)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/from/#{sender_id}", direction: "forward")
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, & &1["call_txi"])
      assert Enum.all?(aex9_transfers, &aex9_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)
      assert ^next_aex9_transfers = Enum.sort_by(next_aex9_transfers, & &1["call_txi"])
      assert List.first(next_aex9_transfers)["call_txi"] >= List.last(aex9_transfers)["call_txi"]
      assert Enum.all?(next_aex9_transfers, &aex9_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn} do
      account_id_without_transfer = enc_id(:crypto.strong_rand_bytes(32))

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
      recipient_id = enc_id(@to_pk1)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/to/#{recipient_id}")
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, & &1["call_txi"], :desc)
      assert Enum.all?(aex9_transfers, &aex9_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)
      assert ^next_aex9_transfers = Enum.sort_by(next_aex9_transfers, & &1["call_txi"], :desc)
      assert List.first(next_aex9_transfers)["call_txi"] <= List.last(aex9_transfers)["call_txi"]
      assert Enum.all?(next_aex9_transfers, &aex9_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "gets aex9 transfers sorted by asc txi", %{conn: conn, store: store} do
      recipient_id = enc_id(@to_pk2)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/to/#{recipient_id}", direction: "forward")
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, & &1["call_txi"])
      assert Enum.all?(aex9_transfers, &aex9_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)
      assert ^next_aex9_transfers = Enum.sort_by(next_aex9_transfers, & &1["call_txi"])
      assert List.first(next_aex9_transfers)["call_txi"] >= List.last(aex9_transfers)["call_txi"]
      assert Enum.all?(next_aex9_transfers, &aex9_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn} do
      account_id_without_transfer = enc_id(:crypto.strong_rand_bytes(32))

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
      sender_id = enc_id(@from_pk1)
      recipient_id = enc_id(@to_pk2)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/from-to/#{sender_id}/#{recipient_id}")
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, & &1["call_txi"], :desc)
      assert Enum.all?(aex9_transfers, &aex9_valid_pair_transfer?(sender_id, recipient_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)
      assert ^next_aex9_transfers = Enum.sort_by(next_aex9_transfers, & &1["call_txi"], :desc)
      assert List.first(next_aex9_transfers)["call_txi"] <= List.last(aex9_transfers)["call_txi"]

      assert Enum.all?(
               next_aex9_transfers,
               &aex9_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "gets aex9 transfers sorted by asc txi", %{conn: conn, store: store} do
      sender_id = enc_id(@from_pk2)
      recipient_id = enc_id(@to_pk1)

      assert %{"data" => aex9_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex9/transfers/from-to/#{sender_id}/#{recipient_id}",
                 direction: "forward"
               )
               |> json_response(200)

      assert @default_limit = length(aex9_transfers)
      assert ^aex9_transfers = Enum.sort_by(aex9_transfers, & &1["call_txi"])
      assert Enum.all?(aex9_transfers, &aex9_valid_pair_transfer?(sender_id, recipient_id, &1))

      assert %{"data" => next_aex9_transfers, "prev" => prev_aex9_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex9_transfers)
      assert ^next_aex9_transfers = Enum.sort_by(next_aex9_transfers, & &1["call_txi"])
      assert List.first(next_aex9_transfers)["call_txi"] >= List.last(aex9_transfers)["call_txi"]

      assert Enum.all?(
               next_aex9_transfers,
               &aex9_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => ^aex9_transfers} =
               conn |> with_store(store) |> get(prev_aex9_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn} do
      account_id_without_transfer = enc_id(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> get(
                 "/v2/aex9/transfers/from-to/#{account_id_without_transfer}/#{enc_id(@to_pk1)}"
               )
               |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex9/transfers/from-to/#{invalid_id}/#{enc_id(@to_pk1)}")
               |> json_response(400)
    end
  end

  describe "aex141_transfers_from" do
    test "gets aex141 transfers sorted by desc txi", %{conn: conn, store: store} do
      sender_id = enc_id(@from_pk1)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex141/transfers/from/#{sender_id}")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, & &1["call_txi"], :desc)
      assert Enum.all?(aex141_transfers, &aex141_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)
      assert ^next_aex141_transfers = Enum.sort_by(next_aex141_transfers, & &1["call_txi"], :desc)

      assert List.first(next_aex141_transfers)["call_txi"] <=
               List.last(aex141_transfers)["call_txi"]

      assert Enum.all?(next_aex141_transfers, &aex141_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "gets aex141 transfers sorted by asc txi", %{conn: conn, store: store} do
      sender_id = enc_id(@from_pk2)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex141/transfers/from/#{sender_id}", direction: "forward")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, & &1["call_txi"])
      assert Enum.all?(aex141_transfers, &aex141_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)
      assert ^next_aex141_transfers = Enum.sort_by(next_aex141_transfers, & &1["call_txi"])

      assert List.first(next_aex141_transfers)["call_txi"] >=
               List.last(aex141_transfers)["call_txi"]

      assert Enum.all?(next_aex141_transfers, &aex141_valid_sender_transfer?(sender_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn} do
      account_id_without_transfer = enc_id(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> get("/v2/aex141/transfers/from/#{account_id_without_transfer}")
               |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex141/transfers/from/#{invalid_id}") |> json_response(400)
    end
  end

  describe "aex141_transfers_to" do
    test "gets aex141 transfers sorted by desc txi", %{conn: conn, store: store} do
      recipient_id = enc_id(@to_pk1)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex141/transfers/to/#{recipient_id}")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, & &1["call_txi"], :desc)
      assert Enum.all?(aex141_transfers, &aex141_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)
      assert ^next_aex141_transfers = Enum.sort_by(next_aex141_transfers, & &1["call_txi"], :desc)

      assert List.first(next_aex141_transfers)["call_txi"] <=
               List.last(aex141_transfers)["call_txi"]

      assert Enum.all?(next_aex141_transfers, &aex141_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "gets aex141 transfers sorted by asc txi", %{conn: conn, store: store} do
      recipient_id = enc_id(@to_pk2)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex141/transfers/to/#{recipient_id}", direction: "forward")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, & &1["call_txi"])
      assert Enum.all?(aex141_transfers, &aex141_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)
      assert ^next_aex141_transfers = Enum.sort_by(next_aex141_transfers, & &1["call_txi"])

      assert List.first(next_aex141_transfers)["call_txi"] >=
               List.last(aex141_transfers)["call_txi"]

      assert Enum.all?(next_aex141_transfers, &aex141_valid_recipient_transfer?(recipient_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn} do
      account_id_without_transfer = enc_id(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> get("/v2/aex141/transfers/to/#{account_id_without_transfer}")
               |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex141/transfers/to/#{invalid_id}") |> json_response(400)
    end
  end

  describe "aex141_transfers_from_to" do
    test "gets aex141 transfers sorted by desc txi", %{conn: conn, store: store} do
      sender_id = enc_id(@from_pk1)
      recipient_id = enc_id(@to_pk2)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex141/transfers/from-to/#{sender_id}/#{recipient_id}")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, & &1["call_txi"], :desc)

      assert Enum.all?(
               aex141_transfers,
               &aex141_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)
      assert ^next_aex141_transfers = Enum.sort_by(next_aex141_transfers, & &1["call_txi"], :desc)

      assert List.first(next_aex141_transfers)["call_txi"] <=
               List.last(aex141_transfers)["call_txi"]

      assert Enum.all?(
               next_aex141_transfers,
               &aex141_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "gets aex141 transfers sorted by asc txi", %{conn: conn, store: store} do
      sender_id = enc_id(@from_pk2)
      recipient_id = enc_id(@to_pk1)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex141/transfers/from-to/#{sender_id}/#{recipient_id}",
                 direction: "forward"
               )
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, & &1["call_txi"])

      assert Enum.all?(
               aex141_transfers,
               &aex141_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)
      assert ^next_aex141_transfers = Enum.sort_by(next_aex141_transfers, & &1["call_txi"])

      assert List.first(next_aex141_transfers)["call_txi"] >=
               List.last(aex141_transfers)["call_txi"]

      assert Enum.all?(
               next_aex141_transfers,
               &aex141_valid_pair_transfer?(sender_id, recipient_id, &1)
             )

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "returns empty list when no transfer exists", %{conn: conn} do
      account_id_without_transfer = enc_id(:crypto.strong_rand_bytes(32))

      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> get(
                 "/v2/aex141/transfers/from-to/#{account_id_without_transfer}/#{enc_id(@to_pk1)}"
               )
               |> json_response(200)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ak_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex141/transfers/from-to/#{invalid_id}/#{enc_id(@to_pk1)}")
               |> json_response(400)
    end
  end

  describe "aex141_transfers" do
    test "gets aex141 transfers sorted by desc txi", %{conn: conn, store: store} do
      contract_id = enc_ct(@contract_pk1)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex141/transfers/#{contract_id}")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, & &1["call_txi"], :desc)
      assert Enum.all?(aex141_transfers, &aex141_valid_contract_transfer?(contract_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)
      assert ^next_aex141_transfers = Enum.sort_by(next_aex141_transfers, & &1["call_txi"], :desc)

      assert List.first(next_aex141_transfers)["call_txi"] <=
               List.last(aex141_transfers)["call_txi"]

      assert Enum.all?(next_aex141_transfers, &aex141_valid_contract_transfer?(contract_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "gets aex141 transfers sorted by asc txi", %{conn: conn, store: store} do
      contract_id = enc_ct(@contract_pk2)

      assert %{"data" => aex141_transfers, "next" => next} =
               conn
               |> with_store(store)
               |> get("/v2/aex141/transfers/#{contract_id}", direction: "forward")
               |> json_response(200)

      assert @default_limit = length(aex141_transfers)
      assert ^aex141_transfers = Enum.sort_by(aex141_transfers, & &1["call_txi"])
      assert Enum.all?(aex141_transfers, &aex141_valid_contract_transfer?(contract_id, &1))

      assert %{"data" => next_aex141_transfers, "prev" => prev_aex141_transfers} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_aex141_transfers)
      assert ^next_aex141_transfers = Enum.sort_by(next_aex141_transfers, & &1["call_txi"])

      assert List.first(next_aex141_transfers)["call_txi"] >=
               List.last(aex141_transfers)["call_txi"]

      assert Enum.all?(next_aex141_transfers, &aex141_valid_contract_transfer?(contract_id, &1))

      assert %{"data" => ^aex141_transfers} =
               conn |> with_store(store) |> get(prev_aex141_transfers) |> json_response(200)
    end

    test "returns not found for unknown contract", %{conn: conn} do
      unknown_id = enc_ct(:crypto.strong_rand_bytes(32))
      error_message = "not found: #{unknown_id}"

      assert %{"error" => ^error_message} =
               conn |> get("/v2/aex141/transfers/#{unknown_id}") |> json_response(404)
    end

    test "returns bad request when id is invalid", %{conn: conn} do
      invalid_id = "ct_InvalidId"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex141/transfers/#{invalid_id}") |> json_response(400)
    end
  end

  defp aex9_valid_sender_transfer?(sender_id, %{
         "sender" => sender,
         "recipient" => recipient,
         "call_txi" => call_txi,
         "log_idx" => log_idx,
         "amount" => amount,
         "contract_id" => contract_id
       }) do
    sender == sender_id and recipient in @recipients and call_txi in @txi_range and
      log_idx in @log_index_range and amount in @aex9_amount_range and contract_id in @contracts
  end

  defp aex9_valid_recipient_transfer?(recipient_id, %{
         "sender" => sender,
         "recipient" => recipient,
         "call_txi" => call_txi,
         "log_idx" => log_idx,
         "amount" => amount,
         "contract_id" => contract_id
       }) do
    sender in @senders and recipient == recipient_id and call_txi in @txi_range and
      log_idx in @log_index_range and amount in @aex9_amount_range and contract_id in @contracts
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
         "call_txi" => call_txi,
         "log_idx" => log_idx,
         "token_id" => token_id,
         "contract_id" => ct_id
       }) do
    sender in @senders and recipient in @recipients and call_txi in @txi_range and
      log_idx in @log_index_range and token_id in @aex141_token_range and
      contract_id == ct_id
  end

  defp aex141_valid_sender_transfer?(sender_id, %{
         "sender" => sender,
         "recipient" => recipient,
         "call_txi" => call_txi,
         "log_idx" => log_idx,
         "token_id" => token_id,
         "contract_id" => contract_id
       }) do
    sender == sender_id and recipient in @recipients and call_txi in @txi_range and
      log_idx in @log_index_range and token_id in @aex141_token_range and
      contract_id in @contracts
  end

  defp aex141_valid_recipient_transfer?(recipient_id, %{
         "sender" => sender,
         "recipient" => recipient,
         "call_txi" => call_txi,
         "log_idx" => log_idx,
         "token_id" => token_id,
         "contract_id" => contract_id
       }) do
    sender in @senders and recipient == recipient_id and call_txi in @txi_range and
      log_idx in @log_index_range and token_id in @aex141_token_range and
      contract_id in @contracts
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
end
