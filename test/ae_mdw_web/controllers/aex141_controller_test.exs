defmodule AeMdwWeb.Aex141ControllerTest do
  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  alias AeMdw.AexnContracts
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Store
  alias AeMdw.Stats
  alias AeMdw.Validate

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1, enc_id: 1]
  import Mock

  require Model

  @owner_pk1 :crypto.strong_rand_bytes(32)
  @owner_pk2 :crypto.strong_rand_bytes(32)
  @default_limit 10

  setup_all _context do
    empty_store =
      NullStore.new()
      |> MemStore.new()

    store =
      Enum.reduce(1_411..1_413, empty_store, fn i, store ->
        meta_info = {"some-nft-#{i}", "SAEX#{i}", "http://some-url.com", :url}
        txi = 1_000 + i

        m_aex141 =
          Model.aexn_contract(index: {:aex141, <<i::256>>}, txi: txi, meta_info: meta_info)

        Store.put(store, Model.AexnContract, m_aex141)
      end)

    contract_pk = <<1_412::256>>

    store =
      Enum.reduce(1_412_001..1_412_005, store, fn j, store ->
        token_id = j
        m_ownership = Model.nft_ownership(index: {@owner_pk1, contract_pk, token_id})
        m_owner_token = Model.nft_owner_token(index: {contract_pk, @owner_pk1, token_id})
        m_token_owner = Model.nft_token_owner(index: {contract_pk, token_id}, owner: @owner_pk1)

        store
        |> Store.put(Model.NftOwnership, m_ownership)
        |> Store.put(Model.NftOwnerToken, m_owner_token)
        |> Store.put(Model.NftTokenOwner, m_token_owner)
      end)

    contract_pk = <<1_413::256>>

    store =
      Enum.reduce(1_413_001..1_413_040, store, fn j, store ->
        token_id = j - 1_413_000
        template_id = j - 1_413_000
        txi = j
        owner_pk = if rem(j, 2) == 0, do: @owner_pk1, else: @owner_pk2
        m_ownership = Model.nft_ownership(index: {owner_pk, contract_pk, token_id})
        m_owner_token = Model.nft_owner_token(index: {contract_pk, owner_pk, token_id})
        m_token_owner = Model.nft_token_owner(index: {contract_pk, token_id}, owner: owner_pk)

        m_template =
          Model.nft_template(
            index: {contract_pk, template_id},
            txi: txi,
            log_idx: rem(template_id, 2)
          )

        store =
          store
          |> Store.put(Model.NftTemplate, m_template)
          |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>))

        if token_id != 1_413_010 do
          store
          |> Store.put(Model.NftOwnership, m_ownership)
          |> Store.put(Model.NftOwnerToken, m_owner_token)
          |> Store.put(Model.NftTokenOwner, m_token_owner)
        else
          store
        end
      end)

    owner_pk = :crypto.strong_rand_bytes(32)
    token_id = 1_413_010
    m_ownership = Model.nft_ownership(index: {owner_pk, contract_pk, token_id})
    m_owner_token = Model.nft_owner_token(index: {contract_pk, owner_pk, token_id})
    m_token_owner = Model.nft_token_owner(index: {contract_pk, token_id}, owner: owner_pk)

    store =
      store
      |> Store.put(Model.NftOwnership, m_ownership)
      |> Store.put(Model.NftOwnerToken, m_owner_token)
      |> Store.put(Model.NftTokenOwner, m_token_owner)

    [store: store, random_owner_pk: owner_pk]
  end

  describe "aex141_contract" do
    test "returns a contract by pubkey", %{conn: conn, store: store} do
      ct_pk = :crypto.strong_rand_bytes(32)
      contract_id = enc_ct(ct_pk)
      txi = Enum.random(1_000_000..9_999_999)
      limit_txi = txi + 1

      meta_info =
        {name, symbol, base_url, _type} =
        {"single-nft", "SAEX141-single", "http://some-url.com/#{txi}", :url}

      extensions = ["extension1", "extension2"]

      m_aex141 =
        Model.aexn_contract(
          index: {:aex141, ct_pk},
          txi: txi,
          meta_info: meta_info,
          extensions: extensions
        )

      m_limits =
        Model.nft_contract_limits(
          index: ct_pk,
          token_limit: 200,
          template_limit: 100,
          txi: limit_txi,
          log_idx: 1
        )

      m_nft_count = Model.stat(index: Stats.nfts_count_key(ct_pk), payload: 6)
      m_owners_count = Model.stat(index: Stats.nft_owners_count_key(ct_pk), payload: 4)

      store =
        store
        |> Store.put(Model.AexnContract, m_aex141)
        |> Store.put(Model.NftContractLimits, m_limits)
        |> Store.put(Model.Stat, m_nft_count)
        |> Store.put(Model.Stat, m_owners_count)

      assert %{
               "name" => ^name,
               "symbol" => ^symbol,
               "base_url" => ^base_url,
               "metadata_type" => "url",
               "nfts_amount" => 6,
               "nft_owners" => 4,
               "contract_txi" => ^txi,
               "contract_id" => ^contract_id,
               "extensions" => ^extensions,
               "token_limit" => 200,
               "template_limit" => 100,
               "limit_txi" => ^limit_txi,
               "limit_log_idx" => 1
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
           call_contract: fn _pk, "owner", [_token_id] ->
             {:ok, {:variant, [0, 1], 1, {{:address, account_pk}}}}
           end
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

    test "when token is invalid, it returns an error", %{conn: conn} do
      contract_id = "ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo"
      token_id = "123abc"
      error_msg = "not found: #{token_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/aex141/#{contract_id}/owner/#{token_id}") |> json_response(404)
    end
  end

  describe "owned-nfts" do
    test "returns an empty list when account owns none", %{conn: conn} do
      account_id = enc_id(:crypto.strong_rand_bytes(32))

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn |> get("/aex141/owned-nfts/#{account_id}") |> json_response(200)
    end

    test "returns a backward list of nfts owned by an account", %{conn: conn, store: store} do
      account_id = enc_id(@owner_pk1)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> with_store(store)
               |> get("/aex141/owned-nfts/#{account_id}")
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort(nfts, :desc)

      assert Enum.any?(nfts, fn %{"owner_id" => owner_id} -> owner_id == account_id end)

      assert %{"data" => next_nfts, "prev" => prev_nfts} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort(next_nfts, :desc)

      assert Enum.any?(next_nfts, fn %{"owner_id" => owner_id} -> owner_id == account_id end)

      assert %{"data" => ^nfts} =
               conn |> with_store(store) |> get(prev_nfts) |> json_response(200)
    end

    test "returns a forward list of nfts owned by an account", %{conn: conn, store: store} do
      account_id = enc_id(@owner_pk1)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> with_store(store)
               |> get("/aex141/owned-nfts/#{account_id}", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort(nfts)

      contract_ids = [enc_ct(<<1_412::256>>), enc_ct(<<1_413::256>>)]

      assert Enum.any?(nfts, fn %{"owner_id" => owner_id, "contract_id" => ct_id} ->
               owner_id == account_id and ct_id in contract_ids
             end)

      refute Enum.any?(nfts, fn %{"token_id" => token_id} -> token_id == 1_413_010 end)

      assert %{"data" => next_nfts, "prev" => prev_nfts} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort(next_nfts)

      assert Enum.any?(next_nfts, fn %{"owner_id" => owner_id, "contract_id" => ct_id} ->
               owner_id == account_id and ct_id in contract_ids
             end)

      refute Enum.any?(nfts, fn %{"token_id" => token_id} -> token_id == 1_413_010 end)

      assert %{"data" => ^nfts} =
               conn |> with_store(store) |> get(prev_nfts) |> json_response(200)
    end
  end

  describe "collection_owners" do
    test "returns an empty list when collection has no nft", %{conn: conn, store: store} do
      contract_id = enc_ct(<<1_411::256>>)

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn
               |> with_store(store)
               |> get("/aex141/#{contract_id}/owners")
               |> json_response(200)
    end

    test "returns collection owners sorted by ascending token_id", %{
      conn: conn,
      store: store,
      random_owner_pk: random_owner_pk
    } do
      contract_id = enc_ct(<<1_413::256>>)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> with_store(store)
               |> get("/aex141/#{contract_id}/owners", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort_by(nfts, & &1["token_id"])

      owner_ids = [enc_id(@owner_pk1), enc_id(@owner_pk2), enc_id(random_owner_pk)]

      assert Enum.all?(nfts, fn %{
                                  "contract_id" => ct_id,
                                  "owner_id" => owner_id,
                                  "token_id" => token_id
                                } ->
               ct_id == contract_id and
                 assert owner_id in owner_ids and token_id in 1..10
             end)

      assert %{"data" => next_nfts, "prev" => prev_nfts} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort_by(next_nfts, & &1["token_id"])

      assert Enum.all?(next_nfts, fn %{
                                       "contract_id" => ct_id,
                                       "owner_id" => owner_id,
                                       "token_id" => token_id
                                     } ->
               ct_id == contract_id and owner_id in owner_ids and token_id in 11..20
             end)

      assert %{"data" => ^nfts} =
               conn |> with_store(store) |> get(prev_nfts) |> json_response(200)
    end

    test "returns collection owners sorted by descending token id", %{conn: conn, store: store} do
      contract_id = enc_ct(<<1_413::256>>)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> with_store(store)
               |> get("/aex141/#{contract_id}/owners")
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort_by(nfts, & &1["token_id"], :desc)
      assert Enum.all?(nfts, &(&1["contract_id"] == contract_id))

      assert %{"data" => next_nfts, "prev" => prev_nfts} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort_by(next_nfts, & &1["token_id"], :desc)
      assert Enum.all?(next_nfts, &(&1["contract_id"] == contract_id))

      assert %{"data" => ^nfts} =
               conn |> with_store(store) |> get(prev_nfts) |> json_response(200)
    end
  end

  describe "collection_templates" do
    test "returns an empty list when collection has no nft", %{conn: conn, store: store} do
      contract_id = enc_ct(<<1_411::256>>)

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn
               |> with_store(store)
               |> get("/aex141/#{contract_id}/templates")
               |> json_response(200)
    end

    test "returns collection templates sorted by ascending ids", %{
      conn: conn,
      store: store
    } do
      contract_id = enc_ct(<<1_413::256>>)

      assert %{"data" => templates, "next" => next} =
               conn
               |> with_store(store)
               |> get("/aex141/#{contract_id}/templates", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(templates)
      assert ^templates = Enum.sort_by(templates, & &1["template_id"])

      assert Enum.all?(templates, fn %{
                                       "contract_id" => ct_id,
                                       "template_id" => template_id,
                                       "tx_hash" => tx_hash,
                                       "log_idx" => log_idx
                                     } ->
               tx_hash = Validate.id!(tx_hash)

               ct_id == contract_id and template_id in 1..10 and
                 tx_hash == <<template_id + 1_413_000::256>> and log_idx == rem(template_id, 2)
             end)

      assert %{"data" => next_templates, "prev" => prev_templates} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_templates)
      assert ^next_templates = Enum.sort_by(next_templates, & &1["template_id"])

      assert Enum.all?(next_templates, fn %{
                                            "contract_id" => ct_id,
                                            "template_id" => template_id,
                                            "tx_hash" => tx_hash,
                                            "log_idx" => log_idx
                                          } ->
               tx_hash = Validate.id!(tx_hash)

               ct_id == contract_id and template_id in 11..20 and
                 tx_hash == <<template_id + 1_413_000::256>> and log_idx == rem(template_id, 2)
             end)

      assert %{"data" => ^templates} =
               conn |> with_store(store) |> get(prev_templates) |> json_response(200)
    end

    test "returns collection templates sorted by descending ids", %{conn: conn, store: store} do
      contract_id = enc_ct(<<1_413::256>>)

      assert %{"data" => templates, "next" => next} =
               conn
               |> with_store(store)
               |> get("/aex141/#{contract_id}/templates")
               |> json_response(200)

      assert @default_limit = length(templates)
      assert ^templates = Enum.sort_by(templates, & &1["template_id"], :desc)
      assert Enum.all?(templates, &(&1["contract_id"] == contract_id))

      assert %{"data" => next_templates, "prev" => prev_templates} =
               conn |> with_store(store) |> get(next) |> json_response(200)

      assert @default_limit = length(next_templates)
      assert ^next_templates = Enum.sort_by(next_templates, & &1["template_id"], :desc)
      assert Enum.all?(next_templates, &(&1["contract_id"] == contract_id))

      assert %{"data" => ^templates} =
               conn |> with_store(store) |> get(prev_templates) |> json_response(200)
    end
  end
end
