defmodule AeMdwWeb.Aex141ControllerTest do
  use ExUnit.Case, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.AexnContracts
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Stats
  alias AeMdw.Validate

  import AeMdw.Util.Encoding, only: [encode_contract: 1, encode_account: 1]
  import AeMdw.TestUtil, only: [empty_store: 0, with_store: 2]
  import Mock

  import Phoenix.ConnTest
  @endpoint AeMdwWeb.Endpoint

  require Model

  @owner_pk1 :crypto.strong_rand_bytes(32)
  @owner_pk2 :crypto.strong_rand_bytes(32)
  @contract_owner_pk1 <<1_413::256>>
  @default_limit 10

  setup_all _context do
    store =
      Enum.reduce(1_411..1_414, empty_store(), fn i, store ->
        meta_info = {"some-nft-#{i}", "SAEX#{i}", "http://some-url.com", :url}
        txi = 1_000 + i

        m_aex141 =
          Model.aexn_contract(
            index: {:aex141, <<i::256>>},
            txi_idx: {txi, -1},
            meta_info: meta_info
          )

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

    contract_pk = @contract_owner_pk1

    store =
      Enum.reduce(1_413_001..1_413_040, store, fn j, store ->
        token_id = j - 1_413_000
        owner_pk = if rem(j, 2) == 0, do: @owner_pk1, else: @owner_pk2
        m_ownership = Model.nft_ownership(index: {owner_pk, contract_pk, token_id})
        m_owner_token = Model.nft_owner_token(index: {contract_pk, owner_pk, token_id})
        m_token_owner = Model.nft_token_owner(index: {contract_pk, token_id}, owner: owner_pk)

        template_id = token_id
        txi = j
        log_idx = rem(template_id, 2)

        m_template =
          Model.nft_template(
            index: {contract_pk, template_id},
            txi: txi,
            log_idx: log_idx,
            limit: {template_id * 10, txi + 100, log_idx + 1}
          )

        m_template_token =
          Model.nft_template_token(
            index: {contract_pk, template_id, token_id + 2},
            txi: txi + 200,
            log_idx: log_idx + 2
          )

        m_stat =
          Model.stat(index: Stats.nft_template_tokens_key(contract_pk, template_id), payload: 3)

        store =
          store
          |> Store.put(Model.NftTemplate, m_template)
          |> Store.put(Model.NftTemplateToken, m_template_token)
          |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>))
          |> Store.put(Model.Tx, Model.tx(index: txi + 100, id: <<txi + 100::256>>))
          |> Store.put(Model.Tx, Model.tx(index: txi + 200, id: <<txi + 200::256>>))

        if token_id != 10 do
          store
          |> Store.put(Model.NftOwnership, m_ownership)
          |> Store.put(Model.NftOwnerToken, m_owner_token)
          |> Store.put(Model.NftTokenOwner, m_token_owner)
        else
          store
          |> Store.put(Model.Stat, m_stat)
        end
      end)

    contract_pk = <<1_414::256>>
    template_id = 10

    m_template =
      Model.nft_template(
        index: {contract_pk, template_id},
        txi: 1_414_000,
        log_idx: 0
      )

    store =
      store
      |> Store.put(Model.Tx, Model.tx(index: 1_414_000, id: <<1_414_000::256>>))
      |> Store.put(Model.NftTemplate, Model.nft_template(m_template, index: {contract_pk, 1}))
      |> Store.put(Model.NftTemplate, m_template)

    store =
      Enum.reduce(1_414_001..1_414_040, store, fn j, store ->
        token_id = j - 1_414_000
        owner_pk = if rem(j, 2) == 0, do: @owner_pk1, else: @owner_pk2

        m_ownership = Model.nft_ownership(index: {owner_pk, contract_pk, token_id})
        m_owner_token = Model.nft_owner_token(index: {contract_pk, owner_pk, token_id})
        m_token_owner = Model.nft_token_owner(index: {contract_pk, token_id}, owner: owner_pk)

        txi = j
        log_idx = rem(token_id, 2)

        m_template_token =
          Model.nft_template_token(
            index: {contract_pk, template_id, token_id},
            txi: txi + 200,
            log_idx: log_idx + 2
          )

        store
        |> Store.put(Model.NftOwnership, m_ownership)
        |> Store.put(Model.NftOwnerToken, m_owner_token)
        |> Store.put(Model.NftTokenOwner, m_token_owner)
        |> Store.put(Model.NftTemplateToken, m_template_token)
        |> Store.put(Model.Tx, Model.tx(index: txi + 200, id: <<txi + 200::256>>))
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

    [conn: with_store(build_conn(), store), random_owner_pk: owner_pk, store: store]
  end

  describe "aex141_contract" do
    test "returns a contract by pubkey", %{conn: %{assigns: %{state: state}} = conn} do
      ct_pk = :crypto.strong_rand_bytes(32)
      contract_id = encode_contract(ct_pk)
      txi = Enum.random(1_000_000..9_999_999)
      limit_txi = txi + 1
      decoded_tx_hash = <<txi::256>>
      tx_hash = Enc.encode(:tx_hash, decoded_tx_hash)
      decoded_limit_tx_hash = <<limit_txi::256>>
      limit_tx_hash = Enc.encode(:tx_hash, decoded_limit_tx_hash)

      meta_info =
        {name, symbol, base_url, _type} =
        {"single-nft", "SAEX141-single", "http://some-url.com/#{txi}", :url}

      extensions = ["extension1", "extension2"]

      m_aex141 =
        Model.aexn_contract(
          index: {:aex141, ct_pk},
          txi_idx: {txi, -1},
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

      time = 5

      height = 1
      block_index = {height, -1}

      m_tx = Model.tx(index: txi, id: decoded_tx_hash, block_index: block_index, time: time)
      m_limit_tx = Model.tx(index: limit_txi, id: decoded_limit_tx_hash)

      block_hash = <<1::256>>

      m_block = Model.block(index: block_index, tx_index: 10, hash: block_hash)

      store =
        state.store
        |> Store.put(Model.Block, m_block)
        |> Store.put(Model.AexnContract, m_aex141)
        |> Store.put(Model.NftContractLimits, m_limits)
        |> Store.put(Model.Stat, m_nft_count)
        |> Store.put(Model.Stat, m_owners_count)
        |> Store.put(Model.Tx, m_tx)
        |> Store.put(Model.Tx, m_limit_tx)

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
               "creation_time" => ^time,
               "block_height" => ^height,
               "limits" => %{
                 "token_limit" => 200,
                 "template_limit" => 100,
                 "limit_txi" => ^limit_txi,
                 "limit_log_idx" => 1
               }
             } =
               conn |> with_store(store) |> get("/v2/aex141/#{contract_id}") |> json_response(200)

      assert %{
               "name" => ^name,
               "symbol" => ^symbol,
               "base_url" => ^base_url,
               "metadata_type" => "url",
               "nfts_amount" => 6,
               "nft_owners" => 4,
               "contract_tx_hash" => ^tx_hash,
               "contract_id" => ^contract_id,
               "extensions" => ^extensions,
               "creation_time" => ^time,
               "limits" => %{
                 "token_limit" => 200,
                 "template_limit" => 100,
                 "limit_tx_hash" => ^limit_tx_hash,
                 "limit_log_idx" => 1
               }
             } =
               conn |> with_store(store) |> get("/v3/aex141/#{contract_id}") |> json_response(200)
    end

    test "returns a contract without token and template limit", %{
      conn: %{assigns: %{state: state}} = conn
    } do
      ct_pk = :crypto.strong_rand_bytes(32)
      contract_id = encode_contract(ct_pk)
      txi = Enum.random(1_000_000..9_999_999)
      limit_txi = txi + 1
      decoded_tx_hash = <<txi::256>>
      tx_hash = Enc.encode(:tx_hash, decoded_tx_hash)

      meta_info =
        {name, symbol, base_url, _type} =
        {"single-nft", "SAEX141-single", "http://some-url.com/#{txi}", :url}

      extensions = ["extension1", "extension2"]

      m_aex141 =
        Model.aexn_contract(
          index: {:aex141, ct_pk},
          txi_idx: {txi, -1},
          meta_info: meta_info,
          extensions: extensions
        )

      m_limits =
        Model.nft_contract_limits(
          index: ct_pk,
          token_limit: nil,
          template_limit: nil,
          txi: limit_txi,
          log_idx: 1
        )

      m_nft_count = Model.stat(index: Stats.nfts_count_key(ct_pk), payload: 6)
      m_owners_count = Model.stat(index: Stats.nft_owners_count_key(ct_pk), payload: 4)

      time = 5

      height = 1
      block_index = {height, -1}

      m_tx = Model.tx(index: txi, id: decoded_tx_hash, block_index: block_index, time: time)

      block_hash = <<1::256>>

      m_block = Model.block(index: block_index, tx_index: 10, hash: block_hash)

      store =
        state.store
        |> Store.put(Model.Block, m_block)
        |> Store.put(Model.AexnContract, m_aex141)
        |> Store.put(Model.NftContractLimits, m_limits)
        |> Store.put(Model.Stat, m_nft_count)
        |> Store.put(Model.Stat, m_owners_count)
        |> Store.put(Model.Tx, m_tx)

      assert %{
               "name" => ^name,
               "symbol" => ^symbol,
               "base_url" => ^base_url,
               "metadata_type" => "url",
               "nfts_amount" => 6,
               "nft_owners" => 4,
               "contract_tx_hash" => ^tx_hash,
               "contract_id" => ^contract_id,
               "extensions" => ^extensions,
               "creation_time" => ^time,
               "limits" => nil
             } =
               conn |> with_store(store) |> get("/v3/aex141/#{contract_id}") |> json_response(200)
    end
  end

  describe "aex141_contracts" do
    setup %{conn: %{assigns: %{state: state}} = conn} do
      store =
        Enum.reduce(1_410_001..1_410_025, state.store, fn i, store ->
          meta_info =
            {name, symbol, _url, _type} =
            {"some-nft-#{i}", "SAEX#{i}", "http://some-url.com", :url}

          txi = 1_000 + i
          decoded_tx_hash = <<txi::256>>

          m_aex141 =
            Model.aexn_contract(
              index: {:aex141, <<i::256>>},
              txi_idx: {txi, -1},
              meta_info: meta_info
            )

          m_aexn_name = Model.aexn_contract_name(index: {:aex141, name, <<i::256>>})

          m_aexn_downcased_name =
            Model.aexn_contract_downcased_name(
              index: {:aex141, String.downcase(name), <<i::256>>},
              original_name: name
            )

          m_aexn_symbol = Model.aexn_contract_symbol(index: {:aex141, symbol, <<i::256>>})

          m_aexn_downcased_symbol =
            Model.aexn_contract_downcased_symbol(
              index: {:aex141, String.downcase(symbol), <<i::256>>},
              original_symbol: symbol
            )

          time = 5

          block_index = {1, -1}

          block_hash = <<1::256>>

          m_aexn_tx =
            Model.aexn_contract_creation(index: {:aex141, {txi, -1}}, contract_pk: <<i::256>>)

          m_tx = Model.tx(index: txi, id: decoded_tx_hash, block_index: block_index, time: time)

          m_block = Model.block(index: block_index, tx_index: 10, hash: block_hash)

          store
          |> Store.put(Model.Block, m_block)
          |> Store.put(Model.AexnContract, m_aex141)
          |> Store.put(Model.AexnContractName, m_aexn_name)
          |> Store.put(Model.AexnContractDowncasedName, m_aexn_downcased_name)
          |> Store.put(Model.AexnContractSymbol, m_aexn_symbol)
          |> Store.put(Model.AexnContractDowncasedSymbol, m_aexn_downcased_symbol)
          |> Store.put(Model.AexnContractCreation, m_aexn_tx)
          |> Store.put(Model.Tx, m_tx)
        end)

      {:ok, conn: with_store(conn, store)}
    end

    test "sorts contracts by name", %{conn: conn} do
      assert %{"data" => contracts} = conn |> get("/v2/aex141", by: "name") |> json_response(200)

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

    test "sorts v3 contracts by name", %{conn: conn} do
      assert %{"data" => contracts} = conn |> get("/v3/aex141", by: "name") |> json_response(200)

      assert length(contracts) > 0

      names = contracts |> Enum.map(fn %{"name" => name} -> name end)
      assert ^names = Enum.sort(names, :desc)

      assert Enum.all?(contracts, fn %{
                                       "name" => name,
                                       "symbol" => symbol,
                                       "contract_tx_hash" => tx_hash,
                                       "contract_id" => contract_id
                                     } ->
               assert is_binary(name) and is_binary(symbol) and is_binary(tx_hash)

               assert match?({:ok, <<_pk::256>>}, Validate.id(contract_id))
               assert match?({:ok, <<_pk::256>>}, Validate.id(tx_hash))
             end)
    end

    test "sorts contracts by symbol", %{conn: conn} do
      assert %{"data" => contracts} =
               conn |> get("/v2/aex141", by: "symbol") |> json_response(200)

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

    test "sorts v3 contracts by symbol", %{conn: conn} do
      assert %{"data" => contracts} =
               conn |> get("/v3/aex141", by: "symbol") |> json_response(200)

      assert length(contracts) > 0

      symbols = contracts |> Enum.map(fn %{"symbol" => symbol} -> symbol end)
      assert ^symbols = Enum.sort(symbols, :desc)

      assert Enum.all?(contracts, fn %{
                                       "name" => name,
                                       "symbol" => symbol,
                                       "contract_tx_hash" => tx_hash,
                                       "contract_id" => contract_id
                                     } ->
               assert is_binary(name) and is_binary(symbol) and is_binary(tx_hash)

               assert match?({:ok, <<_pk::256>>}, Validate.id(contract_id))
               assert match?({:ok, <<_pk::256>>}, Validate.id(tx_hash))
             end)
    end

    Enum.each(["v2", "v3"], fn api_version ->
      test "filters #{api_version} contracts by name prefix", %{conn: conn} do
        prefix = "some-nft-1410"

        assert %{"data" => contracts} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", by: "name", prefix: prefix)
                 |> json_response(200)

        assert length(contracts) > 0
        assert Enum.all?(contracts, fn %{"name" => name} -> String.starts_with?(name, prefix) end)
      end

      test "filters #{api_version} contracts by symbol prefix", %{conn: conn} do
        prefix = "SAEX1410"

        assert %{"data" => contracts} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", by: "symbol", prefix: prefix)
                 |> json_response(200)

        assert length(contracts) > 0

        assert Enum.all?(contracts, fn %{"symbol" => symbol} ->
                 String.starts_with?(symbol, prefix)
               end)
      end

      test "when invalid filters in #{api_version}, it returns an error", %{conn: conn} do
        assert %{"error" => _error_msg} =
                 conn
                 |> get("/#{unquote(api_version)}/aex141", by: "unknown")
                 |> json_response(400)
      end
    end)
  end

  describe "nft_owner" do
    test "returns the account that owns a nft", %{conn: conn} do
      contract_id = encode_contract(<<1_411::256>>)
      account_pk = :crypto.strong_rand_bytes(32)
      result = {:variant, [1, 1], 1, {%{foo: "bar"}}}
      token_id = 123

      with_mocks [
        {AexnContracts, [:passthrough],
         [
           call_contract: fn
             <<1_411::256>>, "owner", [^token_id] ->
               {:ok, {:variant, [0, 1], 1, {{:address, account_pk}}}}

             <<1_411::256>>, "metadata", [^token_id] ->
               {:ok, {:variant, [0, 1], 1, {result}}}
           end
         ]}
      ] do
        assert %{
                 "owner" => account_id,
                 "token_id" => ^token_id,
                 "metadata" => %{"map" => %{"foo" => "bar"}}
               } =
                 conn |> get("/v2/aex141/#{contract_id}/owner/#{token_id}") |> json_response(200)

        assert {:ok, ^account_pk} = Validate.id(account_id)
      end
    end

    test "returns an error when not an aex141 contract", %{conn: conn} do
      non_existent_id = "ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo"
      error_msg = "not AEX141 contract: #{non_existent_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v3/aex141/#{non_existent_id}/tokens/#{123}") |> json_response(400)
    end

    test "returns an error when token doesn't exist", %{conn: conn} do
      contract_id = encode_contract(<<1_411::256>>)
      error_msg = "invalid contract return: \"foo\""

      with_mocks [
        {AexnContracts, [:passthrough],
         [
           call_contract: fn <<1_411::256>>, "owner", [_token_id] -> {:ok, "foo"} end
         ]}
      ] do
        assert %{"error" => ^error_msg} =
                 conn |> get("/v2/aex141/#{contract_id}/owner/#{234}") |> json_response(400)
      end
    end

    test "when token is invalid, it returns an error", %{conn: conn} do
      contract_id = "ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo"
      token_id = "123abc"
      error_msg = "not found: #{token_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/v3/aex141/#{contract_id}/tokens/#{token_id}") |> json_response(404)
    end
  end

  describe "owned-nfts" do
    test "returns an empty list when account owns none", %{conn: conn} do
      account_id = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn |> get("/v2/aex141/owned-nfts/#{account_id}") |> json_response(200)
    end

    test "returns a backward list of nfts owned by an account", %{conn: conn} do
      account_id = encode_account(@owner_pk1)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> get("/v2/aex141/owned-nfts/#{account_id}")
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort(nfts, :desc)

      assert Enum.all?(nfts, &(&1["owner_id"] == account_id))

      assert %{"data" => next_nfts, "prev" => prev_nfts} = conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort(next_nfts, :desc)

      refute Enum.any?(nfts, &(&1["token_id"] == 10))
      assert Enum.all?(next_nfts, &(&1["owner_id"] == account_id))

      assert %{"data" => ^nfts} = conn |> get(prev_nfts) |> json_response(200)
    end

    test "returns a forward list of nfts owned by an account", %{conn: conn} do
      account_id = encode_account(@owner_pk1)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> get("/v2/aex141/owned-nfts/#{account_id}", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort(nfts)

      refute Enum.any?(nfts, &(&1["token_id"] == 10))
      assert Enum.all?(nfts, &(&1["owner_id"] == account_id))

      assert Enum.all?(
               [encode_contract(<<1_412::256>>), encode_contract(<<1_413::256>>)],
               fn ct_id -> Enum.any?(nfts, &(&1["contract_id"] == ct_id)) end
             )

      assert %{"data" => next_nfts, "prev" => prev_nfts} = conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort(next_nfts)

      assert Enum.all?(next_nfts, &(&1["owner_id"] == account_id))

      assert %{"data" => ^nfts} = conn |> get(prev_nfts) |> json_response(200)
    end

    test "returns a backward list of nfts owned by an account on a collection", %{conn: conn} do
      account_id = encode_account(@owner_pk1)
      contract_id = encode_contract(@contract_owner_pk1)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> get("/v2/aex141/owned-nfts/#{account_id}", contract: contract_id)
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort(nfts, :desc)

      assert Enum.all?(nfts, fn %{"owner_id" => owner_id, "contract_id" => ^contract_id} ->
               owner_id == account_id
             end)

      assert %{"data" => next_nfts, "prev" => prev_nfts} = conn |> get(next) |> json_response(200)

      assert length(next_nfts) == @default_limit - 1
      assert ^next_nfts = Enum.sort(next_nfts, :desc)

      assert Enum.all?(next_nfts, fn %{"owner_id" => owner_id, "contract_id" => ^contract_id} ->
               owner_id == account_id
             end)

      assert %{"data" => ^nfts} = conn |> get(prev_nfts) |> json_response(200)
    end

    test "returns a forward list of collection nfts owned by an account on a collection", %{
      conn: conn
    } do
      account_id = encode_account(@owner_pk1)
      contract_id = encode_contract(@contract_owner_pk1)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> get("/v2/aex141/owned-nfts/#{account_id}",
                 direction: :forward,
                 contract: contract_id
               )
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort(nfts)

      refute Enum.any?(nfts, &(&1["token_id"] == 10))
      assert Enum.all?(nfts, &(&1["owner_id"] == account_id and &1["contract_id"] == contract_id))

      assert %{"data" => next_nfts, "prev" => prev_nfts} = conn |> get(next) |> json_response(200)

      assert length(next_nfts) == @default_limit - 1
      assert ^next_nfts = Enum.sort(next_nfts)

      assert Enum.all?(
               next_nfts,
               &(&1["owner_id"] == account_id and &1["contract_id"] == contract_id)
             )

      assert Enum.all?(next_nfts, &(&1["token_id"] > 20))

      assert %{"data" => ^nfts} = conn |> get(prev_nfts) |> json_response(200)
    end
  end

  describe "collection_owners" do
    test "returns an empty list when collection has no nft", %{conn: conn} do
      contract_id = encode_contract(<<1_411::256>>)

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn
               |> get("/v2/aex141/#{contract_id}/owners")
               |> json_response(200)
    end

    test "returns collection owners sorted by ascending token_id", %{
      conn: conn,
      random_owner_pk: random_owner_pk
    } do
      contract_id = encode_contract(<<1_413::256>>)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> get("/v2/aex141/#{contract_id}/owners", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort_by(nfts, & &1["token_id"])

      owner_ids = [
        encode_account(@owner_pk1),
        encode_account(@owner_pk2),
        encode_account(random_owner_pk)
      ]

      assert Enum.all?(nfts, fn %{
                                  "contract_id" => ct_id,
                                  "owner_id" => owner_id,
                                  "token_id" => token_id
                                } ->
               ct_id == contract_id and
                 assert owner_id in owner_ids and
                          assert(token_id in 1..11)
             end)

      assert %{"data" => next_nfts, "prev" => prev_nfts} = conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort_by(next_nfts, & &1["token_id"])

      assert Enum.all?(next_nfts, fn %{
                                       "contract_id" => ct_id,
                                       "owner_id" => owner_id,
                                       "token_id" => token_id
                                     } ->
               ct_id == contract_id and owner_id in owner_ids and token_id in 12..21
             end)

      assert %{"data" => ^nfts} = conn |> get(prev_nfts) |> json_response(200)
    end

    test "returns collection owners sorted by descending token id", %{conn: conn} do
      contract_id = encode_contract(<<1_413::256>>)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> get("/v2/aex141/#{contract_id}/owners")
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort_by(nfts, & &1["token_id"], :desc)
      assert Enum.all?(nfts, &(&1["contract_id"] == contract_id))

      assert %{"data" => next_nfts, "prev" => prev_nfts} = conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort_by(next_nfts, & &1["token_id"], :desc)
      assert Enum.all?(next_nfts, &(&1["contract_id"] == contract_id))

      assert %{"data" => ^nfts} = conn |> get(prev_nfts) |> json_response(200)
    end
  end

  describe "collection_templates" do
    test "returns an empty list when collection has no nft", %{conn: conn} do
      contract_id = encode_contract(<<1_411::256>>)

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn
               |> get("/v2/aex141/#{contract_id}/templates")
               |> json_response(200)
    end

    test "returns collection templates sorted by ascending ids", %{
      conn: conn
    } do
      contract_id = encode_contract(<<1_413::256>>)

      assert %{"data" => templates, "next" => next} =
               conn
               |> get("/v2/aex141/#{contract_id}/templates", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(templates)
      assert ^templates = Enum.sort_by(templates, & &1["template_id"])

      assert Enum.all?(templates, fn %{
                                       "contract_id" => ct_id,
                                       "template_id" => template_id,
                                       "tx_hash" => tx_hash,
                                       "log_idx" => log_idx,
                                       "edition" => %{
                                         "limit" => edition_limit,
                                         "limit_tx_hash" => limit_tx_hash,
                                         "limit_log_idx" => limit_log_idx,
                                         "supply" => supply,
                                         "supply_tx_hash" => supply_tx_hash,
                                         "supply_log_idx" => supply_log_idx
                                       }
                                     } ->
               tx_hash = Validate.id!(tx_hash)
               limit_tx_hash = Validate.id!(limit_tx_hash)
               supply_tx_hash = supply_tx_hash && Validate.id!(supply_tx_hash)

               ct_id == contract_id and template_id in 1..10 and
                 tx_hash == <<template_id + 1_413_000::256>> and log_idx == rem(template_id, 2) and
                 edition_limit == template_id * 10 and
                 limit_tx_hash == <<template_id + 1_413_100::256>> and
                 limit_log_idx == rem(template_id, 2) + 1 and
                 (supply_tx_hash == nil or supply_tx_hash == <<template_id + 1_413_200::256>>) and
                 (supply_log_idx == nil or supply_log_idx == rem(template_id, 2) + 2) and
                 (supply == 0 or supply == 3)
             end)

      assert %{"data" => next_templates, "prev" => prev_templates} =
               conn |> get(next) |> json_response(200)

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

      assert %{"data" => ^templates} = conn |> get(prev_templates) |> json_response(200)
    end

    test "returns collection templates sorted by descending ids", %{conn: conn} do
      contract_id = encode_contract(<<1_413::256>>)

      assert %{"data" => templates, "next" => next} =
               conn
               |> get("/v2/aex141/#{contract_id}/templates")
               |> json_response(200)

      assert @default_limit = length(templates)
      assert ^templates = Enum.sort_by(templates, & &1["template_id"], :desc)
      assert Enum.all?(templates, &(&1["contract_id"] == contract_id))

      assert %{"data" => next_templates, "prev" => prev_templates} =
               conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_templates)
      assert ^next_templates = Enum.sort_by(next_templates, & &1["template_id"], :desc)
      assert Enum.all?(next_templates, &(&1["contract_id"] == contract_id))

      assert %{"data" => ^templates} = conn |> get(prev_templates) |> json_response(200)
    end
  end

  describe "collection_template_tokens" do
    test "returns an empty list when collection has no nft from template", %{conn: conn} do
      contract_id = encode_contract(<<1_414::256>>)

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn
               |> get("/v2/aex141/#{contract_id}/templates/1/tokens")
               |> json_response(200)
    end

    test "returns collection templates sorted by ascending ids", %{
      conn: conn,
      store: store
    } do
      contract_pk = <<1_414::256>>
      contract_id = encode_contract(contract_pk)
      template_id = 10

      assert %{"data" => template_tokens, "next" => next} =
               conn
               |> get("/v2/aex141/#{contract_id}/templates/#{template_id}/tokens",
                 direction: :forward
               )
               |> json_response(200)

      assert @default_limit = length(template_tokens)
      assert ^template_tokens = Enum.sort_by(template_tokens, & &1["token_id"])

      assert template_tokens
             |> Enum.with_index(1)
             |> Enum.all?(fn {%{
                                "token_id" => token_id,
                                "owner_id" => owner_id,
                                "tx_hash" => tx_hash,
                                "log_idx" => log_idx
                              }, token_id} ->
               tx_hash = Validate.id!(tx_hash)
               owner_pk = Validate.id!(owner_id)

               {:ok, Model.nft_token_owner(owner: ^owner_pk)} =
                 Store.get(store, Model.NftTokenOwner, {contract_pk, token_id})

               tx_hash == <<1_414_000 + token_id + 200::256>> and log_idx == rem(token_id, 2) + 2
             end)

      assert %{"data" => next_template_tokens, "prev" => prev_template_tokens} =
               conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_template_tokens)
      assert ^next_template_tokens = Enum.sort_by(next_template_tokens, & &1["token_id"])

      assert %{"data" => ^template_tokens} =
               conn |> get(prev_template_tokens) |> json_response(200)
    end

    test "returns collection templates sorted by descending ids", %{conn: conn} do
      contract_pk = <<1_414::256>>
      contract_id = encode_contract(contract_pk)
      template_id = 10

      assert %{"data" => template_tokens, "next" => next} =
               conn
               |> get("/v2/aex141/#{contract_id}/templates/#{template_id}/tokens")
               |> json_response(200)

      assert @default_limit = length(template_tokens)
      assert ^template_tokens = Enum.sort_by(template_tokens, & &1["token_id"], :desc)

      assert %{"data" => next_template_tokens, "prev" => prev_template_tokens} =
               conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_template_tokens)
      assert ^next_template_tokens = Enum.sort_by(next_template_tokens, & &1["token_id"], :desc)

      assert %{"data" => ^template_tokens} =
               conn |> get(prev_template_tokens) |> json_response(200)
    end
  end
end
