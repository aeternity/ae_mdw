defmodule AeMdwWeb.AexnTokenControllerTest do
  use ExUnit.Case

  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Store
  alias AeMdw.Validate

  import AeMdw.Util.Encoding, only: [encode_contract: 1, encode_account: 1]

  import AeMdw.TestUtil, only: [with_store: 2]

  import Phoenix.ConnTest
  @endpoint AeMdwWeb.Endpoint

  import Mock

  require Model

  @default_limit 10
  @aex9_token_id encode_contract(<<210::256>>)
  @aex141_token_id encode_contract(<<311::256>>)

  setup_all _context do
    empty_store =
      NullStore.new()
      |> MemStore.new()

    store =
      Enum.reduce(200..230, empty_store, fn i, store ->
        meta_info =
          if i < 225 do
            {"some-AEX9-#{i}", "SAEX9#{i}", i}
          else
            {"some-AEX9-#{i}", "big#{i}#{String.duplicate("12", 100)}", i}
          end

        {name, symbol, _decimals} = meta_info
        txi = 2_000 - i
        m_aex9 = Model.aexn_contract(index: {:aex9, <<i::256>>}, txi: txi, meta_info: meta_info)
        m_aexn_name = Model.aexn_contract_name(index: {:aex9, name, <<i::256>>})
        m_aexn_symbol = Model.aexn_contract_symbol(index: {:aex9, symbol, <<i::256>>})

        store
        |> Store.put(Model.AexnContract, m_aex9)
        |> Store.put(Model.AexnContractName, m_aexn_name)
        |> Store.put(Model.AexnContractSymbol, m_aexn_symbol)
      end)

    store =
      Enum.reduce(300..330, store, fn i, store ->
        meta_info =
          if i < 325 do
            {"some-nft-#{i}", "NFT#{i}", "some-url", :url}
          else
            {"big#{i}#{String.duplicate("12", 100)}", "NFT#{i}", "some-url", :url}
          end

        {name, symbol, _url, _type} = meta_info
        txi = 3_000 - i
        m_aexn = Model.aexn_contract(index: {:aex141, <<i::256>>}, txi: txi, meta_info: meta_info)
        m_aexn_name = Model.aexn_contract_name(index: {:aex141, name, <<i::256>>})
        m_aexn_symbol = Model.aexn_contract_symbol(index: {:aex141, symbol, <<i::256>>})

        store
        |> Store.put(Model.AexnContract, m_aexn)
        |> Store.put(Model.AexnContractName, m_aexn_name)
        |> Store.put(Model.AexnContractSymbol, m_aexn_symbol)
      end)

    contract_pk = :crypto.strong_rand_bytes(32)

    functions =
      AeMdw.Node.aex9_signatures()
      |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

    type_info = {:fcode, functions, nil, nil}
    AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

    store =
      1..20
      |> Enum.reduce(store, fn i, store ->
        account_pk = <<1_000 + i::256>>
        txi = 1_000_000 + i

        m_balance =
          Model.aex9_event_balance(
            index: {contract_pk, account_pk},
            txi: txi,
            log_idx: i,
            amount: 1_000_000 - i
          )

        block_index = if i > 10, do: {100_001, 1}, else: {100_002, 2}

        store
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>, block_index: block_index))
        |> Store.put(Model.Aex9EventBalance, m_balance)
      end)
      |> Store.put(Model.Block, Model.block(index: {100_001, 1}, hash: <<100_001::256>>))
      |> Store.put(Model.Block, Model.block(index: {100_002, 2}, hash: <<100_002::256>>))

    {:ok, conn: with_store(build_conn(), store), contract_pk: contract_pk}
  end

  describe "aex9_tokens" do
    test "gets aex9 tokens backwards by name", %{conn: conn} do
      assert %{"data" => aex9_tokens, "next" => next} =
               conn |> get("/v2/aex9") |> json_response(200)

      aex9_names = aex9_tokens |> Enum.map(fn %{"name" => name} -> name end) |> Enum.reverse()

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_names = Enum.sort(aex9_names)

      assert %{"data" => next_aex9_tokens, "prev" => prev_aex9_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex9_names =
        next_aex9_tokens |> Enum.map(fn %{"name" => name} -> name end) |> Enum.reverse()

      assert @default_limit = length(next_aex9_tokens)
      assert ^next_aex9_names = Enum.sort(next_aex9_names)
      assert Enum.at(aex9_names, @default_limit - 1) >= Enum.at(next_aex9_names, 0)

      assert %{"data" => ^aex9_tokens} = conn |> get(prev_aex9_tokens) |> json_response(200)
    end

    test "gets aex9 tokens forwards by name", %{conn: conn} do
      assert %{"data" => aex9_tokens, "next" => next} =
               conn
               |> get("/v2/aex9", direction: "forward")
               |> json_response(200)

      aex9_names = Enum.map(aex9_tokens, fn %{"name" => name} -> name end)

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_names = Enum.sort(aex9_names)

      assert %{"data" => next_aex9_tokens, "prev" => prev_aex9_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex9_names = Enum.map(next_aex9_tokens, fn %{"name" => name} -> name end)

      assert @default_limit = length(next_aex9_tokens)
      assert ^next_aex9_names = Enum.sort(next_aex9_names)
      assert Enum.at(aex9_names, @default_limit - 1) <= Enum.at(next_aex9_names, 0)

      assert %{"data" => ^aex9_tokens} = conn |> get(prev_aex9_tokens) |> json_response(200)
    end

    test "gets aex9 tokens filtered by name prefix", %{conn: conn} do
      prefix = "some-AEX"

      assert %{"data" => aex9_tokens} =
               conn |> get("/v2/aex9", prefix: prefix) |> json_response(200)

      assert length(aex9_tokens) > 0
      assert Enum.all?(aex9_tokens, fn %{"name" => name} -> String.starts_with?(name, prefix) end)
    end

    test "gets aex9 tokens having a specific name", %{conn: conn} do
      name = "some-AEX9-223"

      assert %{"data" => [%{"name" => ^name}]} =
               conn
               |> get("/v2/aex9", by: "name", exact: name)
               |> json_response(200)
    end

    test "gets aex9 tokens backwards by symbol", %{conn: conn} do
      assert %{"data" => aex9_tokens, "next" => next} =
               conn |> get("/v2/aex9", by: "symbol") |> json_response(200)

      aex9_symbols =
        aex9_tokens |> Enum.map(fn %{"symbol" => symbol} -> symbol end) |> Enum.reverse()

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_symbols = Enum.sort(aex9_symbols)

      assert %{"data" => next_aex9_tokens, "prev" => prev_aex9_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex9_symbols =
        next_aex9_tokens |> Enum.map(fn %{"symbol" => symbol} -> symbol end) |> Enum.reverse()

      assert @default_limit = length(next_aex9_tokens)
      assert ^next_aex9_symbols = Enum.sort(next_aex9_symbols)
      assert Enum.at(aex9_symbols, @default_limit - 1) >= Enum.at(next_aex9_symbols, 0)

      assert %{"data" => ^aex9_tokens} = conn |> get(prev_aex9_tokens) |> json_response(200)
    end

    test "gets aex9 tokens forwards by symbol", %{conn: conn} do
      assert %{"data" => aex9_tokens, "next" => next} =
               conn
               |> get("/v2/aex9", direction: "forward", by: "symbol")
               |> json_response(200)

      aex9_symbols = Enum.map(aex9_tokens, fn %{"symbol" => symbol} -> symbol end)

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_symbols = Enum.sort(aex9_symbols)

      assert %{"data" => next_aex9_tokens, "prev" => prev_aex9_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex9_symbols = Enum.map(next_aex9_tokens, fn %{"symbol" => symbol} -> symbol end)

      assert @default_limit = length(next_aex9_tokens)
      assert ^next_aex9_symbols = Enum.sort(next_aex9_symbols)
      assert Enum.at(aex9_symbols, @default_limit - 1) <= Enum.at(next_aex9_symbols, 0)

      assert %{"data" => ^aex9_tokens} = conn |> get(prev_aex9_tokens) |> json_response(200)
    end

    test "gets aex9 tokens filtered by symbol prefix", %{conn: conn} do
      prefix = "SAEX9"

      assert %{"data" => aex9_tokens} =
               conn
               |> get("/v2/aex9", by: "symbol", prefix: prefix)
               |> json_response(200)

      assert length(aex9_tokens) > 0

      assert Enum.all?(aex9_tokens, fn %{"symbol" => symbol} ->
               String.starts_with?(symbol, prefix)
             end)
    end

    test "gets aex9 tokens with big symbol filtered by symbol prefix", %{conn: conn} do
      symbol_prefix = "big"

      assert %{"data" => aex9_tokens} =
               conn
               |> get("/v2/aex9", by: "symbol", prefix: symbol_prefix)
               |> json_response(200)

      assert length(aex9_tokens) > 0

      assert Enum.all?(aex9_tokens, fn %{"symbol" => symbol} ->
               String.starts_with?(symbol, symbol_prefix) and String.length(symbol) > 200
             end)
    end

    test "gets aex9 tokens having a specific symbol", %{conn: conn} do
      symbol = "SAEX9212"

      assert %{"data" => [%{"symbol" => ^symbol}]} =
               conn
               |> get("/v2/aex9", by: "symbol", exact: symbol)
               |> json_response(200)
    end

    test "returns an error when invalid cursor", %{conn: conn} do
      cursor = "blah"
      error_msg = "invalid cursor: #{cursor}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex9", cursor: cursor) |> json_response(400)
    end
  end

  describe "aex141_tokens" do
    test "gets aex141 tokens backwards by name", %{conn: conn} do
      assert %{"data" => aex141_tokens, "next" => next} =
               conn |> get("/v2/aex141") |> json_response(200)

      aex141_names = aex141_tokens |> Enum.map(fn %{"name" => name} -> name end) |> Enum.reverse()

      assert @default_limit = length(aex141_tokens)
      assert ^aex141_names = Enum.sort(aex141_names)

      assert %{"data" => next_aex141_tokens, "prev" => prev_aex141_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex141_names =
        next_aex141_tokens |> Enum.map(fn %{"name" => name} -> name end) |> Enum.reverse()

      assert @default_limit = length(next_aex141_tokens)
      assert ^next_aex141_names = Enum.sort(next_aex141_names)
      assert Enum.at(aex141_names, @default_limit - 1) >= Enum.at(next_aex141_names, 0)

      assert %{"data" => ^aex141_tokens} = conn |> get(prev_aex141_tokens) |> json_response(200)
    end

    test "gets aex141 tokens forwards by name", %{conn: conn} do
      assert %{"data" => aex141_tokens, "next" => next} =
               conn
               |> get("/v2/aex141", direction: "forward")
               |> json_response(200)

      aex141_names = Enum.map(aex141_tokens, fn %{"name" => name} -> name end)

      assert @default_limit = length(aex141_tokens)
      assert ^aex141_names = Enum.sort(aex141_names)

      assert %{"data" => next_aex141_tokens, "prev" => prev_aex141_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex141_names = Enum.map(next_aex141_tokens, fn %{"name" => name} -> name end)

      assert @default_limit = length(next_aex141_tokens)
      assert ^next_aex141_names = Enum.sort(next_aex141_names)
      assert Enum.at(aex141_names, @default_limit - 1) <= Enum.at(next_aex141_names, 0)

      assert %{"data" => ^aex141_tokens} = conn |> get(prev_aex141_tokens) |> json_response(200)
    end

    test "gets aex141 tokens filtered by name prefix", %{conn: conn} do
      prefix = "some-nft"

      assert %{"data" => aex141_tokens} =
               conn
               |> get("/v2/aex141", prefix: prefix)
               |> json_response(200)

      assert length(aex141_tokens) > 0

      assert Enum.all?(aex141_tokens, fn %{"name" => name} ->
               String.starts_with?(name, prefix)
             end)
    end

    test "gets aex141 tokens with big name filtered by name prefix", %{conn: conn} do
      name_prefix = "big"

      assert %{"data" => aex141_tokens} =
               conn
               |> get("/v2/aex141", prefix: name_prefix)
               |> json_response(200)

      assert length(aex141_tokens) > 0

      assert Enum.all?(aex141_tokens, fn %{"name" => name} ->
               String.starts_with?(name, name_prefix) and String.length(name) > 200
             end)
    end

    test "gets aex141 tokens backwards by symbol", %{conn: conn} do
      assert %{"data" => aex141_tokens, "next" => next} =
               conn |> get("/v2/aex141", by: "symbol") |> json_response(200)

      aex141_symbols =
        aex141_tokens |> Enum.map(fn %{"symbol" => symbol} -> symbol end) |> Enum.reverse()

      assert @default_limit = length(aex141_tokens)
      assert ^aex141_symbols = Enum.sort(aex141_symbols)

      assert %{"data" => next_aex141_tokens, "prev" => prev_aex141_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex141_symbols =
        next_aex141_tokens |> Enum.map(fn %{"symbol" => symbol} -> symbol end) |> Enum.reverse()

      assert @default_limit = length(next_aex141_tokens)
      assert ^next_aex141_symbols = Enum.sort(next_aex141_symbols)
      assert Enum.at(aex141_symbols, @default_limit - 1) >= Enum.at(next_aex141_symbols, 0)

      assert %{"data" => ^aex141_tokens} = conn |> get(prev_aex141_tokens) |> json_response(200)
    end

    test "gets aex141 tokens forwards by symbol", %{conn: conn} do
      assert %{"data" => aex141_tokens, "next" => next} =
               conn
               |> get("/v2/aex141", direction: "forward", by: "symbol")
               |> json_response(200)

      aex141_symbols = Enum.map(aex141_tokens, fn %{"symbol" => symbol} -> symbol end)

      assert @default_limit = length(aex141_tokens)
      assert ^aex141_symbols = Enum.sort(aex141_symbols)

      assert %{"data" => next_aex141_tokens, "prev" => prev_aex141_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex141_symbols = Enum.map(next_aex141_tokens, fn %{"symbol" => symbol} -> symbol end)

      assert @default_limit = length(next_aex141_tokens)
      assert ^next_aex141_symbols = Enum.sort(next_aex141_symbols)
      assert Enum.at(aex141_symbols, @default_limit - 1) <= Enum.at(next_aex141_symbols, 0)

      assert %{"data" => ^aex141_tokens} = conn |> get(prev_aex141_tokens) |> json_response(200)
    end

    test "gets aex141 tokens filtered by symbol prefix", %{conn: conn} do
      prefix = "NFT"

      assert %{"data" => aex141_tokens} =
               conn
               |> get("/v2/aex141", by: "symbol", prefix: prefix)
               |> json_response(200)

      assert length(aex141_tokens) > 0

      assert Enum.all?(aex141_tokens, fn %{"symbol" => symbol} ->
               String.starts_with?(symbol, prefix)
             end)
    end

    test "returns an error when invalid cursor", %{conn: conn} do
      cursor = "blah"
      error_msg = "invalid cursor: #{cursor}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex141", cursor: cursor)
               |> json_response(400)
    end
  end

  describe "aex9_token" do
    test "returns an aex9 token", %{conn: conn} do
      assert %{"contract_id" => @aex9_token_id} =
               conn
               |> get("/v2/aex9/#{@aex9_token_id}")
               |> json_response(200)
    end

    test "when not found, it returns 404", %{conn: conn} do
      non_existent_id = "ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo"
      error_msg = "not found: #{non_existent_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex9/#{non_existent_id}")
               |> json_response(404)
    end

    test "when id is not valid, it returns 400", %{conn: conn} do
      invalid_id = "blah"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex9/#{invalid_id}") |> json_response(400)
    end

    test "displays tokens with meta info out of gas error", %{conn: conn} do
      contract_pk = :crypto.strong_rand_bytes(32)
      aexn_meta_info = {:out_of_gas_error, :out_of_gas_error, nil}

      %{store: store} =
        Contract.aexn_creation_write(
          conn.assigns.state,
          :aex9,
          aexn_meta_info,
          contract_pk,
          12_345_678,
          [
            "ext1",
            "ext2"
          ]
        )

      contract_id = encode_contract(contract_pk)

      assert %{
               "contract_id" => ^contract_id,
               "name" => "out_of_gas_error",
               "symbol" => "out_of_gas_error",
               "decimals" => nil
             } = conn |> with_store(store) |> get("/v2/aex9/#{contract_id}") |> json_response(200)
    end

    test "displays tokens with meta info format error", %{conn: conn} do
      contract_pk = :crypto.strong_rand_bytes(32)
      aexn_meta_info = {:format_error, :format_error, nil}

      %{store: store} =
        Contract.aexn_creation_write(
          conn.assigns.state,
          :aex9,
          aexn_meta_info,
          contract_pk,
          12_345_678,
          ["ext1"]
        )

      contract_id = encode_contract(contract_pk)

      assert %{
               "contract_id" => ^contract_id,
               "name" => "format_error",
               "symbol" => "format_error",
               "decimals" => nil
             } = conn |> with_store(store) |> get("/v2/aex9/#{contract_id}") |> json_response(200)
    end
  end

  describe "aex141_token" do
    test "returns an aex141 token", %{conn: conn} do
      assert %{"contract_id" => @aex141_token_id} =
               conn
               |> get("/v2/aex141/#{@aex141_token_id}")
               |> json_response(200)
    end

    test "when not found, it returns 404", %{conn: conn} do
      non_existent_id = "ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo"
      error_msg = "not found: #{non_existent_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex141/#{non_existent_id}")
               |> json_response(404)
    end

    test "when id is not valid, it returns 400", %{conn: conn} do
      invalid_id = "blah"
      error_msg = "invalid id: #{invalid_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v2/aex141/#{invalid_id}") |> json_response(400)
    end

    test "displays token with meta info error", %{conn: conn} do
      contract_pk = :crypto.strong_rand_bytes(32)
      aexn_meta_info = {:out_of_gas_error, :out_of_gas_error, :out_of_gas_error, nil}

      %{store: store} =
        Contract.aexn_creation_write(
          conn.assigns.state,
          :aex141,
          aexn_meta_info,
          contract_pk,
          12_345_678,
          [
            "ext1",
            "ext2"
          ]
        )

      contract_id = encode_contract(contract_pk)

      assert %{
               "contract_id" => ^contract_id,
               "name" => "out_of_gas_error",
               "symbol" => "out_of_gas_error",
               "base_url" => "out_of_gas_error",
               "metadata_type" => nil,
               "extensions" => ["ext1", "ext2"]
             } =
               conn |> with_store(store) |> get("/v2/aex141/#{contract_id}") |> json_response(200)
    end
  end

  describe "aex9_event_balances" do
    test "gets ascending event balances for a contract", %{
      conn: conn,
      contract_pk: contract_pk
    } do
      contract_id = encode_contract(contract_pk)

      assert %{"data" => balances, "next" => next} =
               conn
               |> get("/v2/aex9/#{contract_id}/balances", direction: :forward)
               |> json_response(200)

      assert Enum.all?(Enum.with_index(balances, 1), fn {balance, i} ->
               %{
                 "contract_id" => ct_id,
                 "account_id" => account_id,
                 "block_hash" => block_hash,
                 "height" => height,
                 "last_tx_hash" => last_tx_hash,
                 "last_log_idx" => last_log_idx,
                 "amount" => amount
               } = balance

               ct_id == contract_id and
                 Validate.id!(account_id) == <<1_000 + i::256>> and
                 Validate.id!(block_hash) == <<height::256>> and height in [100_001, 100_002] and
                 Validate.id!(last_tx_hash) == <<1_000_000 + i::256>> and
                 last_log_idx == i and amount == 1_000_000 - i
             end)

      assert @default_limit = length(balances)

      assert %{"data" => next_balances, "prev" => prev} = conn |> get(next) |> json_response(200)

      assert Enum.all?(next_balances, fn %{"contract_id" => ct_id} -> ct_id == contract_id end)

      assert @default_limit = length(next_balances)
      assert List.last(balances)["account_id"] < List.first(next_balances)["account_id"]

      assert %{"data" => ^balances} = conn |> get(prev) |> json_response(200)
    end

    test "gets event balances for a contract with limit", %{
      conn: conn,
      contract_pk: contract_pk
    } do
      contract_id = encode_contract(contract_pk)
      limit = 8

      assert %{"data" => balances, "next" => next} =
               conn
               |> get("/v2/aex9/#{contract_id}/balances", limit: limit)
               |> json_response(200)

      assert Enum.all?(balances, fn %{"contract_id" => ct_id} -> ct_id == contract_id end)

      assert limit == length(balances)

      assert %{"data" => next_balances, "prev" => prev_balances} =
               conn |> get(next) |> json_response(200)

      assert Enum.all?(next_balances, fn %{"contract_id" => ct_id} -> ct_id == contract_id end)

      assert limit == length(next_balances)
      assert List.last(balances)["account_id"] > List.first(next_balances)["account_id"]

      assert %{"data" => ^balances} = conn |> get(prev_balances) |> json_response(200)
    end
  end

  describe "aex9_token_balance" do
    setup do
      contract_pk = :crypto.strong_rand_bytes(32)

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      {:ok, contract: contract_pk}
    end

    test "gets actual account balance on a contract", %{conn: conn, contract: contract_pk} do
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000..9_999_999)

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           aex9_balance: fn ^contract_pk, ^account_pk -> {:ok, {amount, <<1::256>>}} end
         ]}
      ] do
        contract_id = encode_contract(contract_pk)
        account_id = encode_account(account_pk)

        assert %{"account" => ^account_id, "amount" => ^amount, "contract" => ^contract_id} =
                 conn
                 |> get("/v2/aex9/#{contract_id}/balances/#{account_id}")
                 |> json_response(200)
      end
    end

    test "returns error for invalid contract id", %{conn: conn} do
      contract_id = "ct_invalid_id"
      account_id = encode_account(:crypto.strong_rand_bytes(32))

      error_msg = "invalid id: #{contract_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex9/#{contract_id}/balances/#{account_id}")
               |> json_response(400)
    end

    test "returns error for unexisting contract id", %{conn: conn} do
      contract_id = encode_contract(:crypto.strong_rand_bytes(32))
      account_id = encode_account(:crypto.strong_rand_bytes(32))

      error_msg = "not AEX9 contract: #{contract_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex9/#{contract_id}/balances/#{account_id}")
               |> json_response(400)
    end

    test "returns error for invalid account id", %{conn: conn, contract: contract_pk} do
      contract_id = encode_contract(contract_pk)
      account_id = "ak_invalid_id"

      error_msg = "invalid id: #{account_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex9/#{contract_id}/balances/#{account_id}")
               |> json_response(400)
    end
  end
end
