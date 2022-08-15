defmodule AeMdwWeb.Aex141ControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.AexnContracts
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Validate

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1, enc_id: 1]
  import Mock

  require Model

  @owner_pk :crypto.strong_rand_bytes(32)
  @default_limit 10

  setup_all _context do
    Enum.each(1_411..1_413, fn i ->
      meta_info = {"some-nft-#{i}", "SAEX#{i}", "http://some-url.com", :url}
      txi = 1_000 + i
      m_aex141 = Model.aexn_contract(index: {:aex141, <<i::256>>}, txi: txi, meta_info: meta_info)
      Database.dirty_write(Model.AexnContract, m_aex141)
    end)

    Enum.each(1_412_001..1_412_010, fn j ->
      m_aex141 = Model.nft_ownership(index: {@owner_pk, <<div(j, 1_000)::256>>, j})
      Database.dirty_write(Model.NftOwnership, m_aex141)
    end)

    m_aex141 =
      Model.nft_ownership(index: {:crypto.strong_rand_bytes(32), <<1413::256>>, 1_413_001})

    Database.dirty_write(Model.NftOwnership, m_aex141)

    Enum.each(1_413_002..1_413_011, fn j ->
      m_aex141 = Model.nft_ownership(index: {@owner_pk, <<div(j, 1_000)::256>>, j})
      Database.dirty_write(Model.NftOwnership, m_aex141)
    end)

    :ok
  end

  describe "aex141_contract" do
    test "returns a contract by pubkey", %{conn: conn, store: store} do
      ct_pk = :crypto.strong_rand_bytes(32)
      contract_id = enc_ct(ct_pk)
      txi = Enum.random(1_000_000..9_999_999)

      meta_info =
        {name, symbol, base_url, _type} =
        {"single-nft", "SAEX141-single", "http://some-url.com/#{txi}", :url}

      m_aex141 = Model.aexn_contract(index: {:aex141, ct_pk}, txi: txi, meta_info: meta_info)

      store = Store.put(store, Model.AexnContract, m_aex141)

      assert %{
               "name" => ^name,
               "symbol" => ^symbol,
               "base_url" => ^base_url,
               "metadata_type" => "url",
               "contract_txi" => ^txi,
               "contract_id" => ^contract_id,
               "extensions" => []
             } = conn |> with_store(store) |> get("/aex141/#{contract_id}") |> json_response(200)
    end
  end

  describe "aex141_contracts" do
    setup %{store: initial_store} do
      store =
        Enum.reduce(1_410_001..1_410_025, initial_store, fn i, store ->
          meta_info =
            {name, symbol, _url, _type} =
            {"some-nft-#{i}", "SAEX#{i}", "http://some-url.com", :url}

          txi = 1_000 + i

          m_aex141 =
            Model.aexn_contract(index: {:aex141, <<i::256>>}, txi: txi, meta_info: meta_info)

          m_aexn_name = Model.aexn_contract_name(index: {:aex141, name, <<i::256>>})
          m_aexn_symbol = Model.aexn_contract_symbol(index: {:aex141, symbol, <<i::256>>})

          store
          |> Store.put(Model.AexnContract, m_aex141)
          |> Store.put(Model.AexnContractName, m_aexn_name)
          |> Store.put(Model.AexnContractSymbol, m_aexn_symbol)
        end)

      {:ok, store: store}
    end

    test "sorts contracts by name", %{conn: conn, store: store} do
      assert %{"data" => contracts} =
               conn |> with_store(store) |> get("/aex141", by: "name") |> json_response(200)

      assert length(contracts) > 0

      names = contracts |> Enum.map(fn %{"name" => name} -> name end)
      assert ^names = Enum.sort(names, :desc)

      assert Enum.all?(contracts, fn %{
                                       "name" => name,
                                       "symbol" => symbol,
                                       "contract_txi" => txi,
                                       "contract_id" => contract_id
                                     } ->
               assert is_binary(name) and is_binary(symbol) and is_integer(txi)

               assert match?({:ok, <<_pk::256>>}, Validate.id(contract_id))
             end)
    end

    test "sorts contracts by symbol", %{conn: conn, store: store} do
      assert %{"data" => contracts} =
               conn |> with_store(store) |> get("/aex141", by: "symbol") |> json_response(200)

      assert length(contracts) > 0

      symbols = contracts |> Enum.map(fn %{"symbol" => symbol} -> symbol end)
      assert ^symbols = Enum.sort(symbols, :desc)

      assert Enum.all?(contracts, fn %{
                                       "name" => name,
                                       "symbol" => symbol,
                                       "contract_txi" => txi,
                                       "contract_id" => contract_id
                                     } ->
               assert is_binary(name) and is_binary(symbol) and is_integer(txi)

               assert match?({:ok, <<_pk::256>>}, Validate.id(contract_id))
             end)
    end

    test "filters contracts by name prefix", %{conn: conn, store: store} do
      prefix = "some-nft-1410"

      assert %{"data" => contracts} =
               conn
               |> with_store(store)
               |> get("/aex141", by: "name", prefix: prefix)
               |> json_response(200)

      assert length(contracts) > 0
      assert Enum.all?(contracts, fn %{"name" => name} -> String.starts_with?(name, prefix) end)
    end

    test "filters contracts by symbol prefix", %{conn: conn, store: store} do
      prefix = "SAEX1410"

      assert %{"data" => contracts} =
               conn
               |> with_store(store)
               |> get("/aex141", by: "symbol", prefix: prefix)
               |> json_response(200)

      assert length(contracts) > 0

      assert Enum.all?(contracts, fn %{"symbol" => symbol} ->
               String.starts_with?(symbol, prefix)
             end)
    end

    test "when invalid filters, it returns an error", %{conn: conn} do
      assert %{"error" => _error_msg} =
               conn |> get("/aex141", by: "unknown") |> json_response(400)
    end
  end

  describe "nft_owner" do
    test "returns the account that owns a nft", %{conn: conn} do
      contract_id = enc_ct(<<1_411::256>>)
      account_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AexnContracts, [],
         [
           is_aex141?: fn pk -> pk == <<1_411::256>> end,
           call_contract: fn _pk, "owner", [_token_id] -> {:ok, {:address, account_pk}} end
         ]}
      ] do
        assert %{"data" => account_id} =
                 conn |> get("/aex141/#{contract_id}/owner/#{123}") |> json_response(200)

        assert {:ok, ^account_pk} = Validate.id(account_id)
      end
    end

    test "returns an error when not an aex141 contract", %{conn: conn} do
      non_existent_id = "ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo"
      error_msg = "not AEX141 contract: #{non_existent_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/aex141/#{non_existent_id}/owner/#{123}") |> json_response(400)
    end

    test "returns an error when token doesn't exist", %{conn: conn} do
      contract_id = enc_ct(<<1_411::256>>)
      error_msg = "invalid return of contract: #{contract_id}"

      with_mocks [
        {AexnContracts, [],
         [
           is_aex141?: fn pk -> pk == <<1_411::256>> end,
           call_contract: fn _pk, "owner", [_token_id] -> {:ok, nil} end
         ]}
      ] do
        assert %{"error" => ^error_msg} =
                 conn |> get("/aex141/#{contract_id}/owner/#{234}") |> json_response(400)
      end
    end
  end

  describe "owned-nfts" do
    test "returns an empty list when account owns none", %{conn: conn} do
      account_id = enc_id(:crypto.strong_rand_bytes(32))

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn |> get("/aex141/owned-nfts/#{account_id}") |> json_response(200)
    end

    test "returns a backward list of nfts owned by an account", %{conn: conn} do
      account_id = enc_id(@owner_pk)

      assert %{"data" => nfts, "next" => next} =
               conn |> get("/aex141/owned-nfts/#{account_id}") |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort(nfts, :desc)

      assert %{"data" => next_nfts, "prev" => prev_nfts} = conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort(next_nfts, :desc)

      assert %{"data" => ^nfts} = conn |> get(prev_nfts) |> json_response(200)
    end

    test "returns a forward list of nfts owned by an account", %{conn: conn} do
      account_id = enc_id(@owner_pk)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> get("/aex141/owned-nfts/#{account_id}", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort(nfts)

      refute Enum.any?(nfts, fn %{"token_id" => token_id} -> token_id == 1_413_001 end)

      assert %{"data" => next_nfts, "prev" => prev_nfts} = conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort(next_nfts)

      assert %{"data" => ^nfts} = conn |> get(prev_nfts) |> json_response(200)
    end
  end
end
