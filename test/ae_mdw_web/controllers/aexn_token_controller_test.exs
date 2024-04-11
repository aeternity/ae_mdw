defmodule AeMdwWeb.AexnTokenControllerTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.State
  alias AeMdw.Validate
  alias AeMdw.Stats

  import AeMdw.Util.Encoding, only: [encode_contract: 1, encode_account: 1, encode: 2]

  import AeMdw.TestUtil, only: [empty_store: 0, with_store: 2]

  import Phoenix.ConnTest
  @endpoint AeMdwWeb.Endpoint

  import Mock

  require Model

  @default_limit 10
  @aex9_token_id encode_contract(<<210::256>>)
  @aex141_token_id encode_contract(<<311::256>>)

  setup_all _context do
    store =
      Enum.reduce(200..230, empty_store(), fn i, store ->
        meta_info =
          if i < 225 do
            {"some-AEX9-#{i}", "SAEX9#{i}", i}
          else
            {"some-AEX9-#{i}", "big#{i}#{String.duplicate("12", 100)}", i}
          end

        {name, symbol, _decimals} = meta_info
        txi = 2_000 - i
        contract_pk = <<i::256>>

        m_aex9 =
          Model.aexn_contract(
            index: {:aex9, contract_pk},
            txi_idx: {txi, -1},
            meta_info: meta_info
          )

        m_aexn_creation =
          Model.aexn_contract_creation(index: {:aex9, {txi, -1}}, contract_pk: contract_pk)

        m_aexn_name = Model.aexn_contract_name(index: {:aex9, name, <<i::256>>})
        m_aexn_symbol = Model.aexn_contract_symbol(index: {:aex9, symbol, <<i::256>>})

        store
        |> Store.put(Model.AexnContract, m_aex9)
        |> Store.put(Model.AexnContractCreation, m_aexn_creation)
        |> Store.put(Model.AexnContractName, m_aexn_name)
        |> Store.put(Model.AexnContractSymbol, m_aexn_symbol)
        |> then(fn store ->
          Enum.reduce(1..i, store, fn i2, store ->
            balance_txi = 1_000_000 + i2
            account_pk = <<1_000 + i2::256>>
            amount = 1_000_000 - i2

            store
            |> Store.put(
              Model.Aex9EventBalance,
              Model.aex9_event_balance(
                index: {contract_pk, account_pk},
                txi: balance_txi,
                amount: amount
              )
            )
            |> Store.put(
              Model.Tx,
              Model.tx(index: balance_txi, id: <<balance_txi::256>>, block_index: {i2, -1})
            )
            |> Store.put(
              Model.Block,
              Model.block(index: {i2, -1}, hash: <<0::256>>)
            )
            |> Store.put(
              Model.Aex9BalanceAccount,
              Model.aex9_balance_account(
                index: {contract_pk, amount, account_pk},
                txi: balance_txi,
                log_idx: i2
              )
            )
          end)
        end)
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>))
        |> Store.put(
          Model.Stat,
          Model.stat(index: Stats.aex9_logs_count_key(<<i::256>>), payload: i)
        )
      end)

    store =
      Store.put(
        store,
        Model.Stat,
        Model.stat(index: AeMdw.Stats.aexn_count_key(:aex9), payload: 31)
      )

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
        decoded_tx_hash = <<txi::256>>

        m_aexn =
          Model.aexn_contract(
            index: {:aex141, <<i::256>>},
            txi_idx: {txi, -1},
            meta_info: meta_info
          )

        m_aexn_name = Model.aexn_contract_name(index: {:aex141, name, <<i::256>>})
        m_aexn_symbol = Model.aexn_contract_symbol(index: {:aex141, symbol, <<i::256>>})

        m_aexn_creation =
          Model.aexn_contract_creation(index: {:aex141, {txi, -1}}, contract_pk: <<i::256>>)

        m_tx = Model.tx(index: txi, id: decoded_tx_hash)

        store
        |> Store.put(Model.AexnContract, m_aexn)
        |> Store.put(Model.AexnContractName, m_aexn_name)
        |> Store.put(Model.AexnContractSymbol, m_aexn_symbol)
        |> Store.put(Model.AexnContractCreation, m_aexn_creation)
        |> Store.put(Model.Tx, m_tx)
      end)

    store =
      Store.put(
        store,
        Model.Stat,
        Model.stat(index: AeMdw.Stats.aexn_count_key(:aex141), payload: 31)
      )

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

    contract_pk2 = :crypto.strong_rand_bytes(32)

    functions =
      AeMdw.Node.aex9_signatures()
      |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

    type_info = {:fcode, functions, nil, nil}
    AeMdw.EtsCache.put(AeMdw.Contract, contract_pk2, {type_info, nil, nil})

    store =
      1..20
      |> Enum.reduce(store, fn i, store ->
        account_pk = <<1_000 + i::256>>
        txi = 1_000_000 + i

        m_balance =
          Model.aex9_balance_account(
            index: {contract_pk2, 1_000_000 - i, account_pk},
            txi: txi,
            log_idx: i
          )

        block_index = if i > 10, do: {100_001, 1}, else: {100_002, 2}

        store
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>, block_index: block_index))
        |> Store.put(Model.Aex9BalanceAccount, m_balance)
      end)

    account_pk = :crypto.strong_rand_bytes(32)

    store =
      Enum.reduce(200..230, store, fn i, store ->
        txi = 1_000_000 + i

        m_presence =
          Model.aex9_account_presence(
            index: {account_pk, <<i::256>>},
            txi: txi
          )

        store
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>, block_index: {100_001, 1}))
        |> Store.put(Model.Aex9AccountPresence, m_presence)
      end)

    {:ok,
     conn: with_store(build_conn(), store),
     account_pk: account_pk,
     contract_pk: contract_pk,
     contract_pk2: contract_pk2}
  end

  describe "aex9_count" do
    test "gets the number of aex9 contracts", %{conn: conn} do
      assert %{"data" => count} = conn |> get("/v2/aex9/count") |> json_response(200)
      assert count == 31
    end
  end

  describe "aex9_logs_count" do
    test "gets the number of aex9 contract logs", %{conn: conn} do
      contract_id = encode_contract(<<200::256>>)

      assert %{"data" => count} =
               conn |> get("/v2/aex9/#{contract_id}/logs-count") |> json_response(200)

      assert count == 200
    end
  end

  describe "aex9_tokens" do
    test "gets aex9 tokens backwards by creation", %{conn: conn} do
      assert %{"data" => aex9_tokens, "next" => next} =
               conn |> get("/v2/aex9", by: "creation") |> json_response(200)

      aex9_txs = aex9_tokens |> Enum.map(& &1["contract_txi"]) |> Enum.reverse()

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_txs = Enum.sort(aex9_txs)

      assert %{"data" => next_aex9_tokens, "prev" => prev_aex9_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex9_txs = next_aex9_tokens |> Enum.map(& &1["contract_txi"]) |> Enum.reverse()

      assert @default_limit = length(next_aex9_tokens)
      assert ^next_aex9_txs = Enum.sort(next_aex9_txs)
      assert Enum.at(aex9_txs, @default_limit - 1) >= Enum.at(next_aex9_txs, 0)

      assert %{"data" => ^aex9_tokens} = conn |> get(prev_aex9_tokens) |> json_response(200)
    end

    test "gets aex9 tokens forwards by creation", %{conn: conn} do
      assert %{"data" => aex9_tokens, "next" => next} =
               conn
               |> get("/v2/aex9", direction: "forward", by: "creation")
               |> json_response(200)

      aex9_txs = Enum.map(aex9_tokens, & &1["contract_txi"])

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_txs = Enum.sort(aex9_txs)

      assert %{"data" => next_aex9_tokens, "prev" => prev_aex9_tokens} =
               conn |> get(next) |> json_response(200)

      next_aex9_txs = Enum.map(next_aex9_tokens, & &1["contract_txi"])

      assert @default_limit = length(next_aex9_tokens)
      assert ^next_aex9_txs = Enum.sort(next_aex9_txs)
      assert Enum.at(aex9_txs, @default_limit - 1) <= Enum.at(next_aex9_txs, 0)

      assert %{"data" => ^aex9_tokens} = conn |> get(prev_aex9_tokens) |> json_response(200)
    end

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

      aex9_names = Enum.map(aex9_tokens, & &1["name"])
      aex9_holders = Enum.map(aex9_tokens, & &1["holders"])

      assert @default_limit = length(aex9_tokens)
      assert ^aex9_names = Enum.sort(aex9_names)
      assert ^aex9_holders = Enum.to_list(200..209)

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

    test "when invalid order by", %{conn: conn} do
      assert %{"error" => "invalid query: by=pubkey"} =
               conn
               |> get("/v2/aex9", by: "pubkey")
               |> json_response(400)
    end
  end

  describe "aex141_count" do
    test "gets the number of aex141 contracts", %{conn: conn} do
      assert %{"data" => count} = conn |> get("/v2/aex141/count") |> json_response(200)
      assert count == 31
    end
  end

  describe "aex141_tokens" do
    Enum.each(["v2", "v3"], fn api_version ->
      key = if api_version == "v2", do: "contract_txi", else: "contract_tx_hash"

      test "gets #{api_version} aex141 tokens backwards by name", %{conn: conn} do
        assert %{"data" => aex141_tokens, "next" => next} =
                 conn |> get("/#{unquote(api_version)}/aex141") |> json_response(200)

        aex141_names =
          aex141_tokens |> Enum.map(fn %{"name" => name} -> name end) |> Enum.reverse()

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

      test "gets #{api_version} aex141 tokens forwards by name", %{conn: conn} do
        assert %{"data" => aex141_tokens, "next" => next} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", direction: "forward")
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

      test "gets #{api_version} aex141 tokens filtered by name prefix", %{conn: conn} do
        prefix = "some-nft"

        assert %{"data" => aex141_tokens} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", prefix: prefix)
                 |> json_response(200)

        assert length(aex141_tokens) > 0

        assert Enum.all?(aex141_tokens, fn %{"name" => name} ->
                 String.starts_with?(name, prefix)
               end)
      end

      test "gets #{api_version} aex141 tokens with big name filtered by name prefix", %{
        conn: conn
      } do
        name_prefix = "big"

        assert %{"data" => aex141_tokens} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", prefix: name_prefix)
                 |> json_response(200)

        assert length(aex141_tokens) > 0

        assert Enum.all?(aex141_tokens, fn %{"name" => name} ->
                 String.starts_with?(name, name_prefix) and String.length(name) > 200
               end)
      end

      test "gets #{api_version} aex141 tokens backwards by symbol", %{conn: conn} do
        assert %{"data" => aex141_tokens, "next" => next} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", by: "symbol")
                 |> json_response(200)

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

      test "gets #{api_version} aex141 tokens forwards by symbol", %{conn: conn} do
        assert %{"data" => aex141_tokens, "next" => next} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", direction: "forward", by: "symbol")
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

      test "gets #{api_version} aex141 tokens backwards by creation", %{conn: conn} do
        assert %{"data" => aex141_tokens, "next" => next} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", by: "creation")
                 |> json_response(200)

        aex141_txs = aex141_tokens |> Enum.map(& &1[unquote(key)]) |> Enum.reverse()

        assert @default_limit = length(aex141_tokens)
        assert ^aex141_txs = Enum.sort(aex141_txs)

        assert %{"data" => next_aex141_tokens, "prev" => prev_aex141_tokens} =
                 conn |> get(next) |> json_response(200)

        next_aex141_txs = next_aex141_tokens |> Enum.map(& &1[unquote(key)]) |> Enum.reverse()

        assert @default_limit = length(next_aex141_tokens)
        assert ^next_aex141_txs = Enum.sort(next_aex141_txs)
        assert Enum.at(aex141_txs, @default_limit - 1) >= Enum.at(next_aex141_txs, 0)

        assert %{"data" => ^aex141_tokens} = conn |> get(prev_aex141_tokens) |> json_response(200)
      end

      test "gets #{api_version} aex141 tokens forwards by creation", %{conn: conn} do
        assert %{"data" => aex141_tokens, "next" => next} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", direction: "forward", by: "creation")
                 |> json_response(200)

        aex141_txs = Enum.map(aex141_tokens, & &1[unquote(key)])

        assert @default_limit = length(aex141_tokens)
        assert ^aex141_txs = Enum.sort(aex141_txs)

        assert %{"data" => next_aex141_tokens, "prev" => prev_aex141_tokens} =
                 conn |> get(next) |> json_response(200)

        next_aex141_txs = Enum.map(next_aex141_tokens, & &1[unquote(key)])

        assert @default_limit = length(next_aex141_tokens)
        assert ^next_aex141_txs = Enum.sort(next_aex141_txs)
        assert Enum.at(aex141_txs, @default_limit - 1) <= Enum.at(next_aex141_txs, 0)

        assert %{"data" => ^aex141_tokens} = conn |> get(prev_aex141_tokens) |> json_response(200)
      end

      test "gets #{api_version} aex141 tokens filtered by symbol prefix", %{conn: conn} do
        prefix = "NFT"

        assert %{"data" => aex141_tokens} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", by: "symbol", prefix: prefix)
                 |> json_response(200)

        assert length(aex141_tokens) > 0

        assert Enum.all?(aex141_tokens, fn %{"symbol" => symbol} ->
                 String.starts_with?(symbol, prefix)
               end)
      end

      test "returns an error when invalid cursor in #{api_version}", %{conn: conn} do
        cursor = "blah"
        error_msg = "invalid cursor: #{cursor}"

        assert %{"error" => ^error_msg} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", cursor: cursor)
                 |> json_response(400)
      end
    end)
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
          {12_345_678, -1},
          [
            "ext1",
            "ext2"
          ]
        )
        |> State.put(Model.Tx, Model.tx(index: 12_345_678, id: <<12_345_678::256>>))

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
          {12_345_678, -1},
          ["ext1"]
        )
        |> State.put(Model.Tx, Model.tx(index: 12_345_678, id: <<12_345_678::256>>))

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
          {12_345_678, -1},
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
      conn: conn
    } do
      contract_id = encode_contract(<<200::256>>)

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

    test "gets descending balances for a contract sorted by amount", %{
      conn: conn,
      contract_pk2: contract_pk2
    } do
      contract_id = encode_contract(contract_pk2)

      assert %{"data" => balances, "next" => next} =
               conn
               |> get("/v2/aex9/#{contract_id}/balances", by: "amount")
               |> json_response(200)

      assert Enum.each(Enum.with_index(balances, 1), fn {balance, i} ->
               %{
                 "contract_id" => ct_id,
                 "account_id" => account_id,
                 "block_hash" => block_hash,
                 "height" => height,
                 "last_tx_hash" => last_tx_hash,
                 "last_log_idx" => last_log_idx,
                 "amount" => amount
               } = balance

               assert ct_id == contract_id
               assert Validate.id!(account_id) == <<1_000 + i::256>>
               assert Validate.id!(block_hash) == <<height::256>> and height in [100_001, 100_002]
               assert Validate.id!(last_tx_hash) == <<1_000_000 + i::256>>
               assert last_log_idx == i and amount == 1_000_000 - i
             end)

      assert @default_limit = length(balances)

      assert %{"data" => next_balances, "prev" => prev} = conn |> get(next) |> json_response(200)

      assert Enum.all?(next_balances, fn %{"contract_id" => ct_id} -> ct_id == contract_id end)

      assert @default_limit = length(next_balances)
      assert List.last(balances)["account_id"] < List.first(next_balances)["account_id"]

      assert %{"data" => ^balances} = conn |> get(prev) |> json_response(200)
    end

    test "gets event balances for a contract with limit", %{conn: conn} do
      contract_id = encode_contract(<<200::256>>)
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

    test "when invalid order by", %{conn: conn, contract_pk: contract_pk} do
      contract_id = encode_contract(contract_pk)

      assert %{"error" => "invalid query: by=foo"} =
               conn
               |> get("/v2/aex9/#{contract_id}/balances", by: "foo")
               |> json_response(400)
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
           aex9_balance: fn ^contract_pk, ^account_pk, nil -> {:ok, {amount, <<1::256>>}} end
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

    test "gets account balance on a contract at a certain block", %{
      conn: conn,
      contract: contract_pk
    } do
      account_pk = :crypto.strong_rand_bytes(32)
      block_hash = :crypto.strong_rand_bytes(32)
      height = Enum.random(1..700_000)
      amount = Enum.random(1_000_000..9_999_999)

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      with_mocks [
        {:aec_chain, [:passthrough], get_block: &{:ok, &1}},
        {:aec_blocks, [:passthrough],
         [
           type: fn ^block_hash -> :micro end,
           height: fn ^block_hash -> height end
         ]},
        {AeMdw.Node.Db, [:passthrough],
         [
           aex9_balance: fn ^contract_pk, ^account_pk, {:micro, ^height, ^block_hash} ->
             {:ok, {amount, <<1::256>>}}
           end
         ]}
      ] do
        contract_id = encode_contract(contract_pk)
        account_id = encode_account(account_pk)

        assert %{"account" => ^account_id, "amount" => ^amount, "contract" => ^contract_id} =
                 conn
                 |> get("/v2/aex9/#{contract_id}/balances/#{account_id}",
                   hash: encode(:micro_block_hash, block_hash)
                 )
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

  describe "aex9_account_balances" do
    test "returns timeout", %{conn: conn, account_pk: account_pk} do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           aex9_balance: fn <<contract_pk::256>>, ^account_pk, _type_hash ->
             Process.sleep(1_000)
             {:ok, {contract_pk, <<1::256>>}}
           end
         ]}
      ] do
        account_id = encode_account(account_pk)

        assert %{"error" => "timeout"} =
                 conn
                 |> get("/v2/aex9/account-balances/#{account_id}")
                 |> json_response(503)
      end
    end

    test "gets account balance of multiple contracts", %{conn: conn, account_pk: account_pk} do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           aex9_balance: fn <<contract_pk::256>>, ^account_pk, _type_hash ->
             amount = contract_pk
             {:ok, {amount, <<1::256>>}}
           end
         ]}
      ] do
        account_id = encode_account(account_pk)

        assert %{"data" => balances, "next" => next} =
                 conn
                 |> get("/v2/aex9/account-balances/#{account_id}")
                 |> json_response(200)

        assert Enum.all?(Enum.with_index(balances), fn {balance, i} ->
                 %{
                   "amount" => amount,
                   "contract_id" => contract_id,
                   "decimals" => decimals,
                   "block_hash" => block_hash,
                   "height" => height,
                   "token_name" => token_name,
                   "token_symbol" => token_symbol,
                   "tx_hash" => tx_hash,
                   "tx_index" => tx_index,
                   "tx_type" => "contract_call_tx"
                 } = balance

                 id = 230 - i

                 if id < 225, do: assert(token_symbol == "SAEX9#{id}")

                 Validate.id!(contract_id) == <<id::256>> and
                   Validate.id!(block_hash) == <<height::256>> and height in [100_001, 100_002] and
                   Validate.id!(tx_hash) == <<1_000_000 + id::256>> and
                   token_name == "some-AEX9-#{id}" and
                   tx_index == 1_000_000 + id and decimals == id and amount == id
               end)

        assert @default_limit = length(balances)
        assert Enum.sort_by(balances, & &1["contract_id"], :desc) == balances

        assert %{"data" => next_balances, "prev" => prev} =
                 conn |> get(next) |> json_response(200)

        assert @default_limit = length(next_balances)
        assert List.last(balances)["contract_id"] > List.first(next_balances)["contract_id"]

        assert %{"data" => ^balances} = conn |> get(prev) |> json_response(200)
      end
    end

    test "returns error for invalid account id", %{conn: conn} do
      account_id = "ak_invalid_id"

      error_msg = "invalid id: #{account_id}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v2/aex9/account-balances/#{account_id}")
               |> json_response(400)
    end
  end
end
