defmodule AeMdwWeb.Aex9ControllerTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Validate

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3]
  import AeMdw.TestUtil, only: [with_store: 2]
  import AeMdw.Util.Encoding
  import Mock

  import Phoenix.ConnTest
  @endpoint AeMdwWeb.Endpoint

  require Model

  @aex9_token_id encode_contract(<<100::256>>)

  setup_all do
    store =
      Enum.reduce(100..125, MemStore.new(NullStore.new()), fn i, store ->
        meta_info = {name, symbol, _decimals} = {"some-AEX9-#{i}", "SAEX9#{i}", i}
        txi = 1_000 - i
        decoded_tx_hash = <<txi::256>>

        m_aex9 =
          Model.aexn_contract(
            index: {:aex9, <<i::256>>},
            txi_idx: {txi, -1},
            meta_info: meta_info
          )

        m_aex9_supply = Model.aex9_initial_supply(index: <<i::256>>, amount: txi + 10)
        m_aex9_balance = Model.aex9_contract_balance(index: <<i::256>>, amount: txi + 20)
        m_aexn_name = Model.aexn_contract_name(index: {:aex9, name, <<i::256>>})

        m_aexn_downcased_name =
          Model.aexn_contract_downcased_name(
            index: {:aex9, String.downcase(name), <<i::256>>},
            original_name: name
          )

        m_aexn_symbol = Model.aexn_contract_symbol(index: {:aex9, symbol, <<i::256>>})

        m_aexn_downcased_symbol =
          Model.aexn_contract_downcased_symbol(
            index: {:aex9, String.downcase(symbol), <<i::256>>},
            original_symbol: symbol
          )

        m_tx = Model.tx(index: txi, id: decoded_tx_hash)

        store
        |> Store.put(Model.AexnContract, m_aex9)
        |> Store.put(Model.Aex9InitialSupply, m_aex9_supply)
        |> Store.put(Model.Aex9ContractBalance, m_aex9_balance)
        |> Store.put(Model.AexnContractName, m_aexn_name)
        |> Store.put(Model.AexnContractDowncasedName, m_aexn_downcased_name)
        |> Store.put(Model.AexnContractSymbol, m_aexn_symbol)
        |> Store.put(Model.AexnContractDowncasedSymbol, m_aexn_downcased_symbol)
        |> Store.put(Model.Tx, m_tx)
      end)

    {:ok, conn: with_store(build_conn(), store)}
  end

  describe "by_name" do
    test "gets aex9 tokens by name", %{conn: conn} do
      assert aex9_tokens = conn |> get("/aex9/by_name") |> json_response(200)
      assert length(aex9_tokens) > 0

      aex9_names = aex9_tokens |> Enum.map(fn %{"name" => name} -> name end)
      assert ^aex9_names = Enum.sort(aex9_names)

      assert Enum.all?(aex9_tokens, fn %{
                                         "name" => name,
                                         "symbol" => symbol,
                                         "decimals" => decimals,
                                         "contract_txi" => txi,
                                         "contract_id" => contract_id,
                                         "initial_supply" => initial_supply,
                                         "event_supply" => event_supply
                                       } ->
               assert is_binary(name) and is_binary(symbol) and is_integer(decimals) and
                        is_integer(txi)

               assert initial_supply == txi + 10
               assert event_supply == txi + 20

               assert match?({:ok, <<_pk::256>>}, Validate.id(contract_id))
             end)
    end

    test "gets aex9 tokens filtered by name prefix", %{conn: conn} do
      prefix = "some-AEX"

      assert aex9_tokens = conn |> get("/aex9/by_name", prefix: prefix) |> json_response(200)
      assert length(aex9_tokens) > 0
      assert Enum.all?(aex9_tokens, fn %{"name" => name} -> String.starts_with?(name, prefix) end)
    end

    test "when invalid filters, it returns an error", %{conn: conn} do
      assert %{"error" => _error_msg} =
               conn |> get("/aex9/by_name", all: "") |> json_response(400)
    end
  end

  describe "by_symbol" do
    test "gets aex9 tokens by symbol", %{conn: conn} do
      assert aex9_tokens = conn |> get("/aex9/by_symbol") |> json_response(200)

      aex9_symbols = aex9_tokens |> Enum.map(fn %{"symbol" => symbol} -> symbol end)
      assert ^aex9_symbols = Enum.sort(aex9_symbols)

      assert Enum.all?(aex9_tokens, fn %{
                                         "name" => name,
                                         "symbol" => symbol,
                                         "decimals" => decimals,
                                         "contract_txi" => txi,
                                         "contract_id" => contract_id
                                       } ->
               assert is_binary(name) and is_binary(symbol) and is_integer(decimals) and
                        is_integer(txi)

               assert match?({:ok, <<_pk::256>>}, Validate.id(contract_id))
             end)
    end

    test "gets aex9 tokens filtered by symbol prefix", %{conn: conn} do
      prefix = "SAEX9"

      assert aex9_tokens = conn |> get("/aex9/by_symbol", prefix: prefix) |> json_response(200)
      assert length(aex9_tokens) > 0

      assert Enum.all?(aex9_tokens, fn %{"symbol" => symbol} ->
               String.starts_with?(symbol, prefix)
             end)
    end
  end

  describe "by_contract" do
    test "returns an aex9 token", %{conn: conn} do
      assert %{"data" => %{"contract_id" => @aex9_token_id}} =
               conn |> get("/aex9/by_contract/#{@aex9_token_id}") |> json_response(200)
    end
  end

  describe "balance_range" do
    test "validates the range", %{conn: conn} do
      account_id = encode_account(:crypto.strong_rand_bytes(32))
      last_kbi = 11
      range = "1-#{last_kbi}"
      error_msg = "invalid range: max range length is 10"

      # credo:disable-for-next-line
      empty_key_blocks = for i <- 0..last_kbi, do: {String.to_atom("kb#{i}"), []}

      with_blockchain %{account: 1_000}, empty_key_blocks do
        assert %{"error" => ^error_msg} =
                 conn
                 |> get("/aex9/balance/gen/#{range}/#{@aex9_token_id}/#{account_id}")
                 |> json_response(400)
      end
    end
  end

  describe "balance" do
    test "returns 400 when contract is unknown", %{conn: conn} do
      contract_id = encode_contract(:crypto.strong_rand_bytes(32))
      account_id = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"error" => <<"not AEX9 contract: ", ^contract_id::binary>>} =
               conn
               |> get("/aex9/balance/#{contract_id}/#{account_id}")
               |> json_response(400)
    end
  end

  describe "balances" do
    test "returns all account balances", %{conn: conn} do
      account_pk = :crypto.strong_rand_bytes(32)

      expected_balances =
        for i <- 1..10 do
          txi = Enum.random(1_000_000..10_000_000)

          %{
            "block_hash" => encode_block(:micro, :crypto.strong_rand_bytes(32)),
            "amount" => Enum.random(100_000_000..999_000_000),
            "contract_id" => encode_contract(:crypto.strong_rand_bytes(32)),
            "height" => div(txi, 1_000),
            "token_name" => "name#{i}",
            "token_symbol" => "symbol#{i}",
            "tx_hash" => :aeser_api_encoder.encode(:tx_hash, :crypto.strong_rand_bytes(32)),
            "tx_index" => txi,
            "tx_type" => "contract_call_tx"
          }
        end

      store =
        Enum.reduce(expected_balances, conn.assigns.state.store, fn %{
                                                                      "amount" => amount,
                                                                      "contract_id" =>
                                                                        contract_id,
                                                                      "height" => height,
                                                                      "token_name" => token_name,
                                                                      "token_symbol" =>
                                                                        token_symbol,
                                                                      "tx_hash" => tx_hash,
                                                                      "tx_index" => txi
                                                                    },
                                                                    store_acc ->
          contract_pk = Validate.id!(contract_id)
          tx_hash = Validate.id!(tx_hash)

          m_contract =
            Model.aexn_contract(
              index: {:aex9, contract_pk},
              meta_info: {token_name, token_symbol, 18}
            )

          m_balance =
            Model.aex9_event_balance(
              index: {contract_pk, account_pk},
              txi: txi,
              amount: amount
            )

          m_presence = Model.aex9_account_presence(index: {account_pk, contract_pk}, txi: txi)

          store_acc
          |> Store.put(Model.Tx, Model.tx(index: txi, id: tx_hash, block_index: {height, 0}))
          |> Store.put(Model.AexnContract, m_contract)
          |> Store.put(Model.Aex9EventBalance, m_balance)
          |> Store.put(Model.Aex9AccountPresence, m_presence)
        end)

      with_mocks [
        {
          AeMdw.Node.Db,
          [],
          [
            get_tx_data: fn tx_hash_bin ->
              %{"block_hash" => block_hash} =
                Enum.find(expected_balances, fn %{"tx_hash" => tx_hash} ->
                  tx_hash_bin == Validate.id!(tx_hash)
                end)

              {Validate.id!(block_hash), :contract_call_tx, nil, nil}
            end
          ]
        }
      ] do
        assert balances_data =
                 conn
                 |> with_store(store)
                 |> get("/aex9/balances/account/#{encode_account(account_pk)}")
                 |> json_response(200)

        assert ^balances_data = Enum.sort_by(balances_data, & &1["tx_index"], :desc)
        assert MapSet.new(balances_data) == MapSet.new(expected_balances)
      end
    end

    test "returns all account balances at a height", %{conn: conn} do
      account_pk = :crypto.strong_rand_bytes(32)
      path_height = 100_001
      block_hash = <<3::256>>
      mb_hash1 = <<1::256>>
      mb_hash2 = <<2::256>>
      contract_pk1 = <<3::256>>
      contract_pk2 = <<4::256>>
      tx_hash1 = :crypto.strong_rand_bytes(32)
      tx_hash2 = :crypto.strong_rand_bytes(32)

      store =
        Store.put(
          conn.assigns.state.store,
          Model.Block,
          Model.block(index: {path_height, -1}, hash: block_hash, tx_index: 12_000_001)
        )

      balance1 = %{
        "block_hash" => encode_block(:micro, mb_hash1),
        "amount" => 1_000_001,
        "contract_id" => encode_contract(contract_pk1),
        "height" => path_height - 1,
        "token_name" => "name#{1}",
        "token_symbol" => "symbol#{1}",
        "tx_hash" => encode(:tx_hash, tx_hash1),
        "tx_index" => 11_000_001,
        "tx_type" => "contract_call_tx"
      }

      balance2 = %{
        "block_hash" => encode_block(:micro, mb_hash2),
        "amount" => 1_000_002,
        "contract_id" => encode_contract(contract_pk2),
        "height" => path_height - 2,
        "token_name" => "name#{2}",
        "token_symbol" => "symbol#{2}",
        "tx_hash" => encode(:tx_hash, tx_hash2),
        "tx_index" => 10_000_001,
        "tx_type" => "contract_call_tx"
      }

      store =
        Enum.reduce([balance1, balance2], store, fn %{
                                                      "block_hash" => block_hash,
                                                      "amount" => amount,
                                                      "contract_id" => contract_id,
                                                      "height" => height,
                                                      "token_name" => token_name,
                                                      "token_symbol" => token_symbol,
                                                      "tx_hash" => tx_hash,
                                                      "tx_index" => txi
                                                    },
                                                    store_acc ->
          block_hash = Validate.id!(block_hash)
          contract_pk = Validate.id!(contract_id)
          tx_hash = Validate.id!(tx_hash)

          m_contract =
            Model.aexn_contract(
              index: {:aex9, contract_pk},
              meta_info: {token_name, token_symbol, 18}
            )

          m_balance =
            Model.aex9_event_balance(
              index: {contract_pk, account_pk},
              txi: txi,
              amount: amount
            )

          m_presence = Model.aex9_account_presence(index: {account_pk, contract_pk}, txi: txi)
          create_txi = txi - 100

          store_acc
          |> Store.put(Model.Tx, Model.tx(index: txi, id: tx_hash, block_index: {height, 0}))
          |> Store.put(
            Model.Block,
            Model.block(index: {height, 0}, hash: block_hash, tx_index: txi - 1)
          )
          |> Store.put(
            Model.Field,
            Model.field(index: {:contract_create_tx, nil, contract_pk, create_txi})
          )
          |> Store.put(Model.ContractCall, Model.contract_call(index: {create_txi, txi}))
          |> Store.put(Model.AexnContract, m_contract)
          |> Store.put(Model.Aex9EventBalance, m_balance)
          |> Store.put(Model.Aex9AccountPresence, m_presence)
        end)

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           aex9_balance: fn ct_pk, ^account_pk, {:key, ^path_height, ^block_hash} = height_hash ->
             amount = if ct_pk == contract_pk1, do: 1_000_001, else: 1_000_002
             {:ok, {amount, height_hash}}
           end,
           get_tx_data: fn tx_hash ->
             mb_hash = if tx_hash == tx_hash1, do: mb_hash1, else: mb_hash2
             {mb_hash, :contract_call_tx, nil, nil}
           end
         ]}
      ] do
        assert balances_data =
                 conn
                 |> with_store(store)
                 |> get("/aex9/balances/gen/#{path_height}/account/#{encode_account(account_pk)}")
                 |> json_response(200)

        assert ^balances_data = Enum.sort_by(balances_data, & &1["tx_index"], :desc)
        assert MapSet.new(balances_data) == MapSet.new([balance1, balance2])
      end
    end
  end

  test "when not a contract id, it returns 400", %{conn: conn} do
    oracle_pk = :crypto.strong_rand_bytes(32)
    encoded_oracle_pk = :aeser_api_encoder.encode(:oracle_pubkey, oracle_pk)
    error_msg = "invalid id: #{encoded_oracle_pk}"

    assert %{"error" => ^error_msg} =
             conn
             |> get("/aex9/balances/#{encoded_oracle_pk}")
             |> json_response(400)
  end

  test "when not aex9 contract, it returns 400", %{conn: conn} do
    contract_pk = :crypto.strong_rand_bytes(32)
    encoded_contract_pk = :aeser_api_encoder.encode(:contract_pubkey, contract_pk)
    error_msg = "not AEX9 contract: #{encoded_contract_pk}"

    assert %{"error" => ^error_msg} =
             conn
             |> get("/aex9/balances/#{encoded_contract_pk}")
             |> json_response(400)
  end
end
