defmodule AeMdwWeb.TxController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Log
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.Continuation, as: Cont
  alias AeMdwWeb.SwaggerParameters
  require Model

  import AeMdwWeb.Util
  import AeMdw.Db.Util

  @type_spend_tx "SpendTx"

  ##########

  def tx(conn, %{"hash" => enc_tx_hash}),
    do: handle_tx_reply(conn, fn -> read_tx_hash(Validate.id!(enc_tx_hash)) end)

  def txi(conn, %{"index" => index}),
    do: handle_tx_reply(conn, fn -> read_tx(Validate.nonneg_int!(index)) end)

  def txs(conn, params),
    do: Cont.response(conn, &json/2, &add_spendtx_details(&1, params))

  def count(conn, _req),
    do: conn |> json(last_txi())

  def count_id(conn, %{"id" => id}),
    do: handle_input(conn, fn -> conn |> json(id_counts(Validate.id!(id))) end)

  ##########

  def db_stream(_, params, scope),
    do: DBS.map(scope, :json, params)

  def id_counts(<<_::256>> = pk) do
    for tx_type <- AE.tx_types(), reduce: %{} do
      counts ->
        tx_counts =
          for {field, pos} <- AE.tx_ids(tx_type), reduce: %{} do
            tx_counts ->
              case read(Model.IdCount, {tx_type, pos, pk}) do
                [] ->
                  tx_counts

                [rec] ->
                  Map.put(tx_counts, field, Model.id_count(rec, :count))
              end
          end

        (map_size(tx_counts) == 0 &&
           counts) ||
          Map.put(counts, tx_type, tx_counts)
    end
  end

  #
  # Private functions
  #
  defp add_spendtx_details(data_txs, %{"account" => account}) do
    Enum.map(data_txs, fn block ->
      spend_tx_recipient =
        if block["tx"]["type"] == @type_spend_tx, do: block["tx"]["recipient_id"]

      if nil != spend_tx_recipient and String.slice(spend_tx_recipient, 0..2) == "nm_" do
        case Validate.plain_name(spend_tx_recipient) do
          {:ok, name} ->
            Map.merge(block, %{"name" => name, "account" => account})
          _ ->
            Log.warn("missing name for name hash #{spend_tx_recipient}")
            block
        end
      else
        block
      end
    end)
  end

  defp add_spendtx_details(data_txs, _), do: data_txs

  defp read_tx_hash(tx_hash) do
    with <<_::256>> = mb_hash <- :aec_db.find_tx_location(tx_hash),
         {:ok, mb_header} <- :aec_chain.get_header(mb_hash),
         height <- :aec_headers.height(mb_header) do
      DBS.map({:gen, height}, & &1)
      |> Enum.find(&(Model.tx(&1, :id) == tx_hash))
    else
      _ -> nil
    end
  end

  defp handle_tx_reply(conn, source_fn),
    do: handle_input(conn, fn -> tx_reply(conn, source_fn.()) end)

  defp tx_reply(conn, []),
    do: tx_reply(conn, nil)

  defp tx_reply(conn, nil),
    do: conn |> send_error(ErrInput.NotFound, "no such transaction")

  defp tx_reply(conn, [model_tx]),
    do: tx_reply(conn, model_tx)

  defp tx_reply(conn, model_tx) when is_tuple(model_tx) and elem(model_tx, 0) == :tx,
    do: conn |> json(Format.to_map(model_tx))

  ##########

  def swagger_definitions do
    %{
      TxResponse:
        swagger_schema do
          title("Response for transaction")
          description("Response schema for transaction")

          properties do
            block_hash(:string, "The block hash", required: true)
            block_height(:integer, "The block height", required: true)
            hash(:string, "The transaction hash", required: true)
            micro_index(:integer, "The micro block index", required: true)
            micro_time(:integer, "The unix timestamp", required: true)
            signatures(:array, "The signatures", required: true)
            tx(:map, "The transaction", required: true)
            tx_index(:integer, "The tarnsaction index", required: true)
          end

          example(%{
            block_hash: "mh_2WkLsh7vj7XCqioewSD8CPjktzcT3tZ2CCKGjd6fm4epVw3Roi",
            block_height: 300_284,
            hash: "th_2Twp3pJeVuwQ7cMSdPQRfpAUWwdMiwx6coVMpRaNSuzFRnDZFk",
            micro_index: 5,
            micro_time: 1_597_619_554_618,
            signatures: [
              "sg_AWSwU7pAh292uU2LsugssYYjX6u9faXGAS5MYo7tRefp6VXxVwjSuABcF4uHK4AG3WCHSKQ1qdUYVoM6RTWj6yvUubqib"
            ],
            tx: %{
              abi_version: 0,
              account_id: "ak_sezvMRsriPfWdphKmv293hEiyeyUYSoqkWqW7AcAuW9jdkCnT",
              fee: 16_592_000_000_000,
              nonce: 290,
              oracle_id: "ok_sezvMRsriPfWdphKmv293hEiyeyUYSoqkWqW7AcAuW9jdkCnT",
              oracle_ttl: %{type: "delta", value: 500},
              query_fee: 20_000_000_000_000,
              query_format: "string",
              response_format: "string",
              type: "OracleRegisterTx",
              version: 1
            },
            tx_index: 14_633_958
          })
        end,
      TxsCountResponse:
        swagger_schema do
          title("Response for transactions count")
          description("Response schema for transactions count")
          type(:integer)
          example(15_479_090)
        end,
      SpendTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in spend txs")
          description("Response schema for transactions count by id in spend txs")

          properties do
            recipient_id(:integer, "Count of times, where given pubkey appears as recipient_id",
              required: false
            )

            sender_id(:integer, "Count of times, where given pubkey appears as sender_id",
              required: false
            )
          end

          example(%{recipient_id: 1, sender_id: 2})
        end,
      OracleRegisterTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in oracle register txs")
          description("Response schema for transactions count by id in oracle register txs")

          properties do
            account_id(:integer, "Count of times, where given pubkey appears as account_id")
          end

          example(%{account_id: 1})
        end,
      OracleResponseTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in oracle response txs")
          description("Response schema for transactions count by id in oracle response txs")

          properties do
            oracle_id(:integer, "Count of times, where given pubkey appears as oracle_id")
          end

          example(%{oracle_id: 5})
        end,
      OracleQueryTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in oracle query txs")
          description("Response schema for transactions count by id in oracle query txs")

          properties do
            oracle_id(:integer, "Count of times, where given pubkey appears as oracle_id",
              required: false
            )

            sender_id(:integer, "Count of times, where given pubkey appears as sender_id:",
              required: false
            )
          end

          example(%{oracle_id: 4, sender_id: 2})
        end,
      OracleExtendTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in oracle extend txs")
          description("Response schema for transactions count by id in oracle extend txs")

          properties do
            oracle_id(:integer, "Count of times, where given pubkey appears as oracle_id")
          end

          example(%{oracle_id: 5})
        end,
      ChannelTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in channel txs")
          description("Response schema for transactions count by id in channel txs")

          properties do
            channel_id(:integer, "Count of times, where given pubkey appears as channel_id",
              required: false
            )

            from_id(:integer, "Count of times, where given pubkey appears as from_id",
              required: false
            )
          end

          example(%{channel_id: 5, from_id: 3})
        end,
      ChannelCreateTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in channel create txs")
          description("Response schema for transactions count by id in channel create txs")

          properties do
            initiator_id(:integer, "Count of times, where given pubkey appears as initiator_id",
              required: false
            )

            responder_id(:integer, "Count of times, where given pubkey appears as responder_id",
              required: false
            )
          end

          example(%{initiator_id: 2, responder_id: 5})
        end,
      ChannelOffchainTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in channel offchain txs")
          description("Response schema for transactions count by id in channel offchain txs")

          properties do
            channel_id(:integer, "Count of times, where given pubkey appears as channel_id")
          end

          example(%{channel_id: 7})
        end,
      ChannelWithdrawTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in channel withdraw txs")
          description("Response schema for transactions count by id in channel withdraw txs")

          properties do
            channel_id(:integer, "Count of times, where given pubkey appears as channel_id",
              required: false
            )

            to_id(:integer, "Count of times, where given pubkey appears as to_id", required: false)
          end

          example(%{channel_id: 8, to_id: 5})
        end,
      ContractCallTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in contract call txs")
          description("Response schema for transactions count by id in contract call txs")

          properties do
            caller_id(:integer, "Count of times, where given pubkey appears as caller_id",
              required: false
            )

            contract_id(:integer, "Count of times, where given pubkey appears as contract_id",
              required: false
            )
          end

          example(%{caller_id: 2, contract_id: 3})
        end,
      ContractTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in contract txs")
          description("Response schema for transactions count by id in contract txs")

          properties do
            owner_id(:integer, "Count of times, where given pubkey appears as owner_id")
          end

          example(%{owner_id: 6})
        end,
      GaMetaTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in ga meta txs")
          description("Response schema for transactions count by id in ga meta txs")

          properties do
            ga_id(:integer, "Count of times, where given pubkey appears as ga_id")
          end

          example(%{ga_id: 12})
        end,
      NamePreclaimTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in name preclaim txs")
          description("Response schema for transactions count by id in name preclaim txs")

          properties do
            account_id(:integer, "Count of times, where given pubkey appears as account_id",
              required: false
            )

            commitment_id(:integer, "Count of times, where given pubkey appears as commitment_id",
              required: false
            )
          end

          example(%{account_id: 2, commitment_id: 3})
        end,
      NameClaimTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in name claim txs")
          description("Response schema for transactions count by id in name claim txs")

          properties do
            account_id(:integer, "Count of times, where given pubkey appears as account_id")
          end

          example(%{account_id: 2})
        end,
      NameTransferTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in name transfer txs")
          description("Response schema for transactions count by id in name transfer txs")

          properties do
            account_id(:integer, "Count of times, where given pubkey appears as account_id",
              required: false
            )

            name_id(:integer, "Count of times, where given pubkey appears as name_id",
              required: false
            )

            recipient_id(:integer, "Count of times, where given pubkey appears as recipient_id",
              required: false
            )
          end

          example(%{account_id: 4, name_id: 3, recipient_id: 6})
        end,
      NameTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in name txs")
          description("Response schema for transactions count by id in name txs")

          properties do
            account_id(:integer, "Count of times, where given pubkey appears as account_id",
              required: false
            )

            name_id(:integer, "Count of times, where given pubkey appears as name_id",
              required: false
            )
          end

          example(%{account_id: 2, name_id: 6})
        end,
      PayingForTxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id in paying for txs")
          description("Response schema for transactions count by id in paying for txs")

          properties do
            payer_id(:integer, "Count of times, where given pubkey appears as payer_id")
          end

          example(%{payer_id: 2})
        end,
      TxsCountByIdResponse:
        swagger_schema do
          title("Response for transactions count by id")
          description("Response schema for transactions count by id")

          properties do
            spend_tx(Schema.ref(:SpendTxsCountByIdResponse), "The spend txs count",
              required: false
            )

            oracle_register_tx(
              Schema.ref(:OracleRegisterTxsCountByIdResponse),
              "The oracle register txs count",
              required: false
            )

            oracle_response_tx(
              Schema.ref(:OracleResponseTxsCountByIdResponse),
              "The oracle response txs count",
              required: false
            )

            oracle_query_tx(
              Schema.ref(:OracleQueryTxsCountByIdResponse),
              "The oracle query txs count",
              required: false
            )

            oracle_extend_tx(
              Schema.ref(:OracleExtendTxsCountByIdResponse),
              "The oracle extend txs count",
              required: false
            )

            channel_close_mutual_tx(
              Schema.ref(:ChannelTxsCountByIdResponse),
              "The channel close mutual txs count",
              required: false
            )

            channel_close_solo_tx(
              Schema.ref(:ChannelTxsCountByIdResponse),
              "The channel close solo txs count",
              required: false
            )

            channel_create_tx(
              Schema.ref(:ChannelCreateTxsCountByIdResponse),
              "The channel create txs count",
              required: false
            )

            channel_deposit_tx(
              Schema.ref(:ChannelTxsCountByIdResponse),
              "The channel deposit txs count",
              required: false
            )

            channel_force_progress_tx(
              Schema.ref(:ChannelTxsCountByIdResponse),
              "The channel force progress txs count",
              required: false
            )

            channel_offchain_tx(
              Schema.ref(:ChannelOffchainTxsCountByIdResponse),
              "The channel offchain txs count",
              required: false
            )

            channel_settle_tx(
              Schema.ref(:ChannelTxsCountByIdResponse),
              "The channel settle txs count",
              required: false
            )

            channel_slash_tx(
              Schema.ref(:ChannelTxsCountByIdResponse),
              "The channel slash txs count",
              required: false
            )

            channel_snapshot_solo_tx(
              Schema.ref(:ChannelTxsCountByIdResponse),
              "The channel snapshot solo txs count",
              required: false
            )

            channel_withdraw_tx(
              Schema.ref(:ChannelWithdrawTxsCountByIdResponse),
              "The channel withdraw txs count",
              required: false
            )

            contract_call_tx(
              Schema.ref(:ContractCallTxsCountByIdResponse),
              "The contract call txs count",
              required: false
            )

            contract_create_tx(
              Schema.ref(:ContractTxsCountByIdResponse),
              "The contract create txs count",
              required: false
            )

            ga_attach_tx(Schema.ref(:ContractTxsCountByIdResponse), "The ga attach txs count",
              required: false
            )

            ga_meta_tx(Schema.ref(:GaMetaTxsCountByIdResponse), "The ga meta txs count",
              required: false
            )

            name_preclaim_tx(
              Schema.ref(:NamePreclaimTxsCountByIdResponse),
              "The name preclaim txs count",
              required: false
            )

            name_claim_tx(Schema.ref(:NameClaimTxsCountByIdResponse), "The name claim txs count",
              required: false
            )

            name_revoke_tx(Schema.ref(:NameTxsCountByIdResponse), "The name revoke txs count",
              required: false
            )

            name_transfer_tx(
              Schema.ref(:NameTransferTxsCountByIdResponse),
              "The name transfer txs count",
              required: false
            )

            name_update_tx(Schema.ref(:NameTxsCountByIdResponse), "The name update txs count",
              required: false
            )

            paying_for_tx(Schema.ref(:PayingForTxsCountByIdResponse), "The paying for txs count",
              required: false
            )
          end

          example(%{
            oracle_extend_tx: %{oracle_id: 2},
            oracle_query_tx: %{oracle_id: 2, sender_id: 2},
            oracle_register_tx: %{account_id: 1},
            oracle_response_tx: %{oracle_id: 2},
            spend_tx: %{recipient_id: 1, sender_id: 2}
          })
        end,
      TxsScopeResponse:
        swagger_schema do
          title("Response for transactions by scope type range")
          description("Response schema for transactions by scope type range")

          properties do
            data(Schema.array(:TxResponse), "The transactions responses", required: true)
            next(:string, "The continuation link", required: true)
          end

          example(%{
            data: [
              %{
                block_hash: "mh_ufiYLdN8am8fBxMnb6xq2K4MQKo4eFSCF5bgixq4EzKMtDUXP",
                block_height: 1,
                hash: "th_2FHxDzpQMRTiRfpYRV3eCcsheHr1sjf9waxk7z6JDTVcgqZRXR",
                micro_index: 0,
                micro_time: 1_543_375_246_712,
                signatures: [
                  "sg_Fipyxq5f3JS9CB3AQVCw1v9skqNBw1cdfe5W3h1t2MkviU19GQckERQZkqkaXWKowdTUvr7B1QbtWdHjJHQcZApwVDdP9"
                ],
                tx: %{
                  amount: 150_425,
                  fee: 101_014,
                  nonce: 1,
                  payload: "ba_NzkwOTIxLTgwMTAxOGSbElc=",
                  recipient_id: "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
                  sender_id: "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
                  type: "SpendTx",
                  version: 1
                },
                tx_index: 0
              },
              %{
                block_hash: "mh_2PGJQKB1jX3gshVn4oshcgaGKAtz96W3PAqzW8giaXNRkjsAND",
                block_height: 155,
                hash: "th_2duufMULhKAadyrEQF5dx35eJT7JpKEY3n7rXznPB1etwQFo5C",
                micro_index: 0,
                micro_time: 1_543_400_251_733,
                signatures: [
                  "sg_GvtmZ5NkN1cK3bcdDuLHbq5Mx6nLnepG2h1acGJdNbAjXQPJkZ36ryRpyED1xdhdSp9rvtc72bF8PEymqphWEVxUHRw2o"
                ],
                tx: %{
                  amount: 1_000_000,
                  fee: 20001,
                  nonce: 2,
                  payload: "ba_SGFucyBkb25hdGVzs/BHFA==",
                  recipient_id: "ak_2fbhvhopqoWbGXbqUHJhZEM1Rm16eMXBqLtDu5iEVqNrASnzF6",
                  sender_id: "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5",
                  type: "SpendTx",
                  version: 1
                },
                tx_index: 1
              }
            ],
            next: "txs/gen/0-265304?limit=2&page=2"
          })
        end,
      ErrorResponse:
        swagger_schema do
          title("Error response")
          description("Error response from the API")

          properties do
            error(:string, "The message of the error raised", required: true)
          end

          example(%{error: "invalid id: th_2Twp3pJeVuwQ7cMSdPQRfpAUWwdMiwx6coVMpRaNSuzFRnDZF"})
        end
    }
  end

  swagger_path :tx do
    get("/tx/{hash}")
    description("Get a transaction by a given hash.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_tx_by_hash")
    tag("Middleware")

    parameters do
      hash(:path, :string, "The transaction hash",
        required: true,
        example: "th_zATv7B4RHS45GamShnWgjkvcrQfZUWQkZ8gk1RD4m2uWLJKnq"
      )
    end

    response(200, "Returns the transaction", Schema.ref(:TxResponse))
    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :txi do
    get("/txi/{index}")
    description("Get a transaction by a given index.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_tx_by_index")
    tag("Middleware")

    parameters do
      index(:path, :integer, "The transaction index", required: true, example: 10_000_000)
    end

    response(200, "Returns the transaction", Schema.ref(:TxResponse))
    response(404, "Not found", Schema.ref(:ErrorResponse))
    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :count do
    get("/txs/count")
    description("Get count of transactions at the current height.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_current_tx_count")
    tag("Middleware")

    response(
      200,
      "Returns count of all transactions at the current height",
      Schema.ref(:TxsCountResponse)
    )
  end

  swagger_path :count_id do
    get("/txs/count/{id}")
    description("Get transactions count and its type for given aeternity ID.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_tx_count_by_id")
    tag("Middleware")

    parameters do
      id(:path, :string, "The ID",
        required: true,
        example: "ak_g5vQK6beY3vsTJHH7KBusesyzq9WMdEYorF8VyvZURXTjLnxT"
      )
    end

    response(
      200,
      "Returns transactions count and its type for given aeternity ID",
      Schema.ref(:TxsCountByIdResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :txs_scope_range do
    get("/txs/{scope_type}/{range}")
    description("Get a transactions bounded by scope/range.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_txs_by_scope_type_range")
    tag("Middleware")
    SwaggerParameters.common_params()
    SwaggerParameters.limit_and_page_params()

    parameters do
      scope_type(:path, :string, "The scope type", enum: [:gen, :txi], required: true)
      range(:path, :string, "The range", required: true, example: "0-265354")
    end

    response(
      200,
      "Returns result regarding the according criteria",
      Schema.ref(:TxsScopeResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :txs_direction do
    get("/txs/{direction}")

    description(
      "Get a transactions from beginning or end of the chain. More [info](https://github.com/aeternity/ae_mdw#transaction-querying)"
    )

    produces(["application/json"])
    deprecated(false)
    operation_id("get_txs_by_direction")
    tag("Middleware")
    SwaggerParameters.common_params()
    SwaggerParameters.limit_and_page_params()

    parameters do
      direction(
        :path,
        :string,
        "The direction - **forward** is from genesis to the end, **backward** is from end to the beginning",
        enum: [:forward, :backward],
        required: true
      )

      sender_id(:query, :string, "The sender ID",
        required: false,
        exaple: "ak_26dopN3U2zgfJG4Ao4J4ZvLTf5mqr7WAgLAq6WxjxuSapZhQg5"
      )

      recipient_id(:query, :string, "The recipient ID",
        required: false,
        exaple: "ak_r7wvMxmhnJ3cMp75D8DUnxNiAvXs8qcdfbJ1gUWfH8Ufrx2A2"
      )
    end

    response(
      200,
      "Returns result regarding the according criteria",
      Schema.ref(:TxsScopeResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  def swagger_path_txs(route = %{path: "/txs/{direction}"}), do: swagger_path_txs_direction(route)

  def swagger_path_txs(route = %{path: "/txs/{scope_type}/{range}"}),
    do: swagger_path_txs_scope_range(route)
end
