defmodule AeMdwWeb.ActiveEntityControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Validate

  require Model

  import AeMdw.TestUtil, only: [empty_store: 0, with_store: 2]
  import Mock

  @call_height 11
  @caller_pk1 :crypto.strong_rand_bytes(32)
  @block_hash :crypto.strong_rand_bytes(32)
  @txi_base Enum.random(10_000_000..99_999_999)
  @price Enum.random(100_000_000..999_999_999)

  @nft_contract "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"
  @default_limit 10

  defp fixtures(store, offset \\ 0, create_txi \\ nil) do
    %Range{
      first: offset + 1,
      last: offset + 20,
      step: 1
    }
    |> Enum.reduce(store, fn i, store ->
      create_txi = create_txi || @txi_base + i - 2

      call_txi = @txi_base + i
      m_entity = Model.entity(index: {"nft_auction", call_txi, create_txi})
      m_contract_entity = Model.contract_entity(index: {"nft_auction", create_txi, call_txi})

      args = [
        %{type: :contract, value: @nft_contract},
        %{type: :int, value: i},
        %{type: :int, value: @price}
      ]

      m_call =
        Model.contract_call(
          index: {create_txi, call_txi},
          fun: "put_listing",
          args: args
        )

      store
      |> Store.put(Model.ActiveEntity, m_entity)
      |> Store.put(Model.ContractEntity, m_contract_entity)
      |> Store.put(Model.ContractCall, m_call)
      |> Store.put(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, <<create_txi::256>>, create_txi})
      )
      |> Store.put(
        Model.Origin,
        Model.origin(index: {:contract_create_tx, <<create_txi::256>>, create_txi})
      )
      |> Store.put(
        Model.RevOrigin,
        Model.rev_origin(index: {create_txi, :contract_create_tx, <<create_txi::256>>})
      )
      |> Store.put(
        Model.Tx,
        Model.tx(index: call_txi, block_index: {@call_height, 0}, id: <<call_txi::256>>)
      )
    end)
  end

  setup_all do
    store1 = fixtures(empty_store())

    create_txi = @txi_base

    store2 =
      empty_store()
      |> fixtures(20, create_txi)

    [
      conn1: with_store(build_conn(), store1),
      conn2: with_store(build_conn(), store2),
      contract_id: encode_contract(<<create_txi::256>>)
    ]
  end

  describe "active_entities" do
    test "returns all active auctions forwards", %{conn1: conn} do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           get_tx_data: &mock_get_tx_data/1
         ]}
      ] do
        assert %{"data" => data, "next" => next} =
                 conn
                 |> get("/v2/entities/nft_auction", direction: "forward")
                 |> json_response(200)

        assert Enum.count(data) == @default_limit

        Enum.with_index(data, fn %{
                                   "height" => @call_height,
                                   "block_hash" => block_hash,
                                   "source_tx_hash" => tx_hash,
                                   "source_tx_type" => "ContractCallTx",
                                   "internal_source" => false,
                                   "tx" => %{
                                     "nonce" => nonce,
                                     "contract_id" => contract_id,
                                     "function" => "put_listing",
                                     "arguments" => args
                                   }
                                 },
                                 i ->
          assert nonce == i + 2
          assert @block_hash == Validate.id!(block_hash)
          assert <<@txi_base + i::256>> == Validate.id!(contract_id)
          assert <<@txi_base + i + 1::256>> == Validate.id!(tx_hash)

          assert args == [
                   %{"type" => "contract", "value" => @nft_contract},
                   %{"type" => "int", "value" => i + 1},
                   %{"type" => "int", "value" => @price}
                 ]
        end)

        assert %{"data" => next_data, "prev" => prev, "next" => nil} =
                 conn
                 |> get(next)
                 |> json_response(200)

        assert Enum.count(next_data) == @default_limit

        Enum.with_index(next_data, fn %{
                                        "height" => @call_height,
                                        "block_hash" => block_hash,
                                        "source_tx_hash" => tx_hash,
                                        "source_tx_type" => "ContractCallTx",
                                        "internal_source" => false,
                                        "tx" => %{
                                          "nonce" => nonce,
                                          "contract_id" => contract_id,
                                          "function" => "put_listing",
                                          "arguments" => args
                                        }
                                      },
                                      i ->
          i = i + 10
          assert nonce == i + 2
          assert @block_hash == Validate.id!(block_hash)
          assert <<@txi_base + i::256>> == Validate.id!(contract_id)
          assert <<@txi_base + i + 1::256>> == Validate.id!(tx_hash)

          assert args == [
                   %{"type" => "contract", "value" => @nft_contract},
                   %{"type" => "int", "value" => i + 1},
                   %{"type" => "int", "value" => @price}
                 ]
        end)

        assert %{"data" => ^data} =
                 conn
                 |> get(prev)
                 |> json_response(200)
      end
    end

    test "returns all active auctions backwards", %{conn1: conn} do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           get_tx_data: &mock_get_tx_data/1
         ]}
      ] do
        assert %{"data" => data, "next" => next} =
                 conn
                 |> get("/v2/entities/nft_auction")
                 |> json_response(200)

        assert Enum.count(data) == @default_limit

        Enum.with_index(data, fn %{
                                   "height" => @call_height,
                                   "block_hash" => block_hash,
                                   "source_tx_hash" => tx_hash,
                                   "source_tx_type" => "ContractCallTx",
                                   "internal_source" => false,
                                   "tx" => %{
                                     "nonce" => nonce,
                                     "contract_id" => contract_id,
                                     "function" => "put_listing",
                                     "arguments" => args
                                   }
                                 },
                                 i ->
          i = 20 - i - 1
          assert nonce == i + 2
          assert @block_hash == Validate.id!(block_hash)
          assert <<@txi_base + i::256>> == Validate.id!(contract_id)
          assert <<@txi_base + i + 1::256>> == Validate.id!(tx_hash)

          assert args == [
                   %{"type" => "contract", "value" => @nft_contract},
                   %{"type" => "int", "value" => i + 1},
                   %{"type" => "int", "value" => @price}
                 ]
        end)

        assert %{"data" => next_data, "prev" => prev} =
                 conn
                 |> get(next)
                 |> json_response(200)

        assert Enum.count(next_data) == @default_limit

        Enum.with_index(next_data, fn %{
                                        "height" => @call_height,
                                        "block_hash" => block_hash,
                                        "source_tx_hash" => tx_hash,
                                        "source_tx_type" => "ContractCallTx",
                                        "internal_source" => false,
                                        "tx" => %{
                                          "nonce" => nonce,
                                          "contract_id" => contract_id,
                                          "function" => "put_listing",
                                          "arguments" => args
                                        }
                                      },
                                      i ->
          i = 10 - i - 1
          assert nonce == i + 2
          assert @block_hash == Validate.id!(block_hash)
          assert <<@txi_base + i::256>> == Validate.id!(contract_id)
          assert <<@txi_base + i + 1::256>> == Validate.id!(tx_hash)

          assert args == [
                   %{"type" => "contract", "value" => @nft_contract},
                   %{"type" => "int", "value" => i + 1},
                   %{"type" => "int", "value" => @price}
                 ]
        end)

        assert %{"data" => ^data} =
                 conn
                 |> get(prev)
                 |> json_response(200)
      end
    end

    test "returns active auctions from a marketplace forwards", %{
      conn2: conn,
      contract_id: marketplace_id
    } do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           get_tx_data: &mock_get_tx_data/1
         ]}
      ] do
        assert %{"data" => data, "next" => next} =
                 conn
                 |> get("/v2/entities/nft_auction", direction: "forward", contract: marketplace_id)
                 |> json_response(200)

        assert Enum.count(data) == @default_limit

        Enum.with_index(data, fn %{
                                   "height" => @call_height,
                                   "block_hash" => block_hash,
                                   "source_tx_hash" => tx_hash,
                                   "source_tx_type" => "ContractCallTx",
                                   "internal_source" => false,
                                   "tx" => %{
                                     "nonce" => nonce,
                                     "contract_id" => contract_id,
                                     "function" => "put_listing",
                                     "arguments" => args
                                   }
                                 },
                                 i ->
          i = i + 21
          assert nonce == i + 1
          assert @block_hash == Validate.id!(block_hash)
          assert <<@txi_base::256>> == Validate.id!(contract_id)
          assert <<@txi_base + i::256>> == Validate.id!(tx_hash)

          assert args == [
                   %{"type" => "contract", "value" => @nft_contract},
                   %{"type" => "int", "value" => i},
                   %{"type" => "int", "value" => @price}
                 ]
        end)

        assert %{"data" => next_data, "prev" => prev, "next" => nil} =
                 conn
                 |> get(next)
                 |> json_response(200)

        assert Enum.count(next_data) == @default_limit

        Enum.with_index(next_data, fn %{
                                        "height" => @call_height,
                                        "block_hash" => block_hash,
                                        "source_tx_hash" => tx_hash,
                                        "source_tx_type" => "ContractCallTx",
                                        "internal_source" => false,
                                        "tx" => %{
                                          "nonce" => nonce,
                                          "contract_id" => contract_id,
                                          "function" => "put_listing",
                                          "arguments" => args
                                        }
                                      },
                                      i ->
          i = i + 31
          assert nonce == i + 1
          assert @block_hash == Validate.id!(block_hash)
          assert <<@txi_base::256>> == Validate.id!(contract_id)
          assert <<@txi_base + i::256>> == Validate.id!(tx_hash)

          assert args == [
                   %{"type" => "contract", "value" => @nft_contract},
                   %{"type" => "int", "value" => i},
                   %{"type" => "int", "value" => @price}
                 ]
        end)

        assert %{"data" => ^data} =
                 conn
                 |> get(prev)
                 |> json_response(200)
      end
    end

    test "returns all active auctions from a marketplace backwards", %{
      conn2: conn,
      contract_id: marketplace_id
    } do
      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           get_tx_data: &mock_get_tx_data/1
         ]}
      ] do
        assert %{"data" => data, "next" => next} =
                 conn
                 |> get("/v2/entities/nft_auction", contract: marketplace_id)
                 |> json_response(200)

        assert Enum.count(data) == @default_limit

        Enum.with_index(data, fn %{
                                   "height" => @call_height,
                                   "block_hash" => block_hash,
                                   "source_tx_hash" => tx_hash,
                                   "source_tx_type" => "ContractCallTx",
                                   "internal_source" => false,
                                   "tx" => %{
                                     "nonce" => nonce,
                                     "contract_id" => contract_id,
                                     "function" => "put_listing",
                                     "arguments" => args
                                   }
                                 },
                                 i ->
          i = 40 - i - 1
          assert nonce == i + 2
          assert @block_hash == Validate.id!(block_hash)
          assert <<@txi_base::256>> == Validate.id!(contract_id)
          assert <<@txi_base + i + 1::256>> == Validate.id!(tx_hash)

          assert args == [
                   %{"type" => "contract", "value" => @nft_contract},
                   %{"type" => "int", "value" => i + 1},
                   %{"type" => "int", "value" => @price}
                 ]
        end)

        assert %{"data" => next_data, "prev" => prev} =
                 conn
                 |> get(next)
                 |> json_response(200)

        assert Enum.count(next_data) == @default_limit

        Enum.with_index(next_data, fn %{
                                        "height" => @call_height,
                                        "block_hash" => block_hash,
                                        "source_tx_hash" => tx_hash,
                                        "source_tx_type" => "ContractCallTx",
                                        "internal_source" => false,
                                        "tx" => %{
                                          "nonce" => nonce,
                                          "contract_id" => contract_id,
                                          "function" => "put_listing",
                                          "arguments" => args
                                        }
                                      },
                                      i ->
          i = 30 - i - 1
          assert nonce == i + 2
          assert @block_hash == Validate.id!(block_hash)
          assert <<@txi_base::256>> == Validate.id!(contract_id)
          assert <<@txi_base + i + 1::256>> == Validate.id!(tx_hash)

          assert args == [
                   %{"type" => "contract", "value" => @nft_contract},
                   %{"type" => "int", "value" => i + 1},
                   %{"type" => "int", "value" => @price}
                 ]
        end)

        assert %{"data" => ^data} =
                 conn
                 |> get(prev)
                 |> json_response(200)
      end
    end

    test "renders not found error when contract does not exist", %{conn2: conn} do
      contract_id = encode_contract(:crypto.strong_rand_bytes(32))
      error_msg = "not found: #{contract_id}"
      conn = get(conn, "/v2/entities/nft_auction", contract: contract_id)

      assert %{"error" => ^error_msg} = json_response(conn, 404)
    end

    test "renders invalid query error when the parameter is unknown", %{conn2: conn} do
      error_msg = "invalid query: {#{"\"foo_param\", \"bar\""}}"
      conn = get(conn, "/v2/entities/nft_auction", foo_param: "bar")

      assert %{"error" => ^error_msg} = json_response(conn, 400)
    end
  end

  defp mock_get_tx_data(<<txi::256>>) when txi > @txi_base and txi < @txi_base + 41 do
    account_id = :aeser_id.create(:account, @caller_pk1)

    contract_id =
      if txi <= @txi_base + 20 do
        :aeser_id.create(:contract, <<txi - 1::256>>)
      else
        :aeser_id.create(:contract, <<@txi_base::256>>)
      end

    nonce = txi - @txi_base + 1

    {:ok, aetx} =
      :aect_call_tx.new(%{
        caller_id: account_id,
        nonce: nonce,
        contract_id: contract_id,
        abi_version: 2,
        fee: 1,
        amount: 10,
        gas: 100,
        gas_price: 1_000,
        call_data: ""
      })

    {tx_type, tx_rec} = :aetx.specialize_type(aetx)
    {@block_hash, tx_type, nil, tx_rec}
  end
end
