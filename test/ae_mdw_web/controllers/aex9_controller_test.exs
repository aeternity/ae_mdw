defmodule AeMdwWeb.Aex9ControllerTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Validate

  import AeMdw.TestUtil, only: [with_store: 2]
  import AeMdw.Util.Encoding
  import Mock

  import Phoenix.ConnTest
  @endpoint AeMdwWeb.Endpoint

  require Model

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

  describe "balance" do
    test "returns 400 when contract is unknown", %{conn: conn} do
      contract_id = encode_contract(:crypto.strong_rand_bytes(32))
      account_id = encode_account(:crypto.strong_rand_bytes(32))

      assert %{"error" => <<"not AEX9 contract: ", ^contract_id::binary>>} =
               conn
               |> get("/v3/aex9/#{contract_id}/balances/#{account_id}")
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
