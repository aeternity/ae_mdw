defmodule AeMdwWeb.Aex9ControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Validate

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1, enc_id: 1, enc_block: 2]
  import Mock

  require Model

  @aex9_token_id enc_ct(<<100::256>>)

  setup_all _context do
    Enum.each(100..125, fn i ->
      meta_info = {name, symbol, _decimals} = {"some-AEX9-#{i}", "SAEX9#{i}", i}
      txi = 1_000 - i
      m_aex9 = Model.aexn_contract(index: {:aex9, <<i::256>>}, txi: txi, meta_info: meta_info)
      m_aexn_name = Model.aexn_contract_name(index: {:aex9, name, <<i::256>>})
      m_aexn_symbol = Model.aexn_contract_symbol(index: {:aex9, symbol, <<i::256>>})
      Database.dirty_write(Model.AexnContract, m_aex9)
      Database.dirty_write(Model.AexnContractName, m_aexn_name)
      Database.dirty_write(Model.AexnContractSymbol, m_aexn_symbol)
    end)

    :ok
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
                                         "contract_id" => contract_id
                                       } ->
               assert is_binary(name) and is_binary(symbol) and is_integer(decimals) and
                        is_integer(txi)

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
    test "it validates the range", %{conn: conn} do
      contract_id = enc_ct(:crypto.strong_rand_bytes(32))
      account_id = enc_id(:crypto.strong_rand_bytes(32))
      last_range = 1_000_000
      error_msg = "invalid range: max range length is 10"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/aex9/balance/gen/1-#{last_range}/#{contract_id}/#{account_id}")
               |> json_response(400)
    end
  end

  describe "balance" do
    test "returns 400 when contract is unknown", %{conn: conn, store: store} do
      contract_id = enc_ct(:crypto.strong_rand_bytes(32))
      account_id = enc_id(:crypto.strong_rand_bytes(32))

      assert %{"error" => <<"not AEX9 contract: ", ^contract_id::binary>>} =
               conn
               |> with_store(store)
               |> get("/aex9/balance/#{contract_id}/#{account_id}")
               |> json_response(400)
    end
  end

  describe "balances" do
    test "returns all account balances", %{conn: conn, store: store} do
      account_pk = :crypto.strong_rand_bytes(32)

      expected_balances =
        for i <- 1..10 do
          txi = Enum.random(1_000_000..10_000_000)

          %{
            "block_hash" => enc_block(:micro, :crypto.strong_rand_bytes(32)),
            "amount" => Enum.random(100_000_000..999_000_000),
            "contract_id" => enc_ct(:crypto.strong_rand_bytes(32)),
            "height" => div(txi, 1_000),
            "token_name" => "name#{i}",
            "token_symbol" => "symbol#{i}",
            "tx_hash" => :aeser_api_encoder.encode(:tx_hash, :crypto.strong_rand_bytes(32)),
            "tx_index" => txi,
            "tx_type" => "contract_call_tx"
          }
        end

      store =
        Enum.reduce(expected_balances, store, fn %{
                                                   "amount" => amount,
                                                   "contract_id" => contract_id,
                                                   "height" => height,
                                                   "token_name" => token_name,
                                                   "token_symbol" => token_symbol,
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
            Model.aex9_balance(
              index: {contract_pk, account_pk},
              block_index: {height, 0},
              txi: txi,
              amount: amount
            )

          m_presence = Model.aex9_account_presence(index: {account_pk, contract_pk}, txi: txi)

          store_acc
          |> Store.put(Model.Tx, Model.tx(index: txi, id: tx_hash, block_index: {height, 0}))
          |> Store.put(Model.AexnContract, m_contract)
          |> Store.put(Model.Aex9Balance, m_balance)
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
                 |> get("/aex9/balances/account/#{enc_id(account_pk)}")
                 |> json_response(200)

        assert ^balances_data = Enum.sort_by(balances_data, & &1["tx_index"], :desc)
        assert MapSet.new(balances_data) == MapSet.new(expected_balances)
      end
    end
  end
end
