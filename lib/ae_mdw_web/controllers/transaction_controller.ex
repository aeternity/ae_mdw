defmodule AeMdwWeb.TransactionController do
  use AeMdwWeb, :controller

  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Db.Stream.Tx, as: DBSTx
  alias AeMdwWeb.Util
  require Model

  # Hardcoded DB only for testing purpose
  @txs_for_account_to_account %{
    "transactions" => [
      %{
        "block_height" => 195_065,
        "block_hash" => "mh_2fsoWrz5cTRKqPdkRJXcnCn5cC444iyZ9jSUVr6w3tR3ipLH2N",
        "hash" => "th_2wZfT7JQRoodrJD5SQkUnHK6ZuwaunDWXYvtaWfE6rNduxDqRb",
        "signatures" => [
          "sg_ZXp5HWs7UkNLaMf9jorjsXvvpCFVMgEWGiFR3LWp1wRXC1u2meEbMYqrxspYdfc8w39QNk5fbqenEPLwezqbWV2U8R5PS"
        ],
        "tx" => %{
          "amount" => 100_000_000_000_000_000_000,
          "fee" => 16_840_000_000_000,
          "nonce" => 2,
          "payload" => "ba_Xfbg4g==",
          "recipient_id" => "ak_2ppoxaXnhSadMM8aw9XBH72cmjse1FET6UkM2zwvxX8fEBbM8U",
          "sender_id" => "ak_S5JTasvPZsbYWbEUFNsme8vz5tqkdhtGx3m7yJC7Dpqi4rS2A",
          "type" => "SpendTx",
          "version" => 1
        }
      }
    ]
  }

  @tx_rate [
    %{
      "amount" => "5980801808761449247022144",
      "count" => 36155,
      "date" => "2019-11-04"
    }
  ]

  def txs_for_account_to_account(conn, _params) do
    json(conn, @txs_for_account_to_account)
  end

  def tx_rate(conn, _params) do
    json(conn, @tx_rate)
  end

  def txs_count_for_account(conn, %{"address" => account}) do
    case :aeser_api_encoder.safe_decode(:account_pubkey, account) do
      {:ok, pk} ->
        count =
          pk
          |> DBS.Object.rev_tx()
          |> Stream.map(&Model.to_map/1)
          |> Enum.count()

        json(conn, %{"count" => count})

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid public key"})
    end

    json(conn, @txs_count_for_account)
  end

  def txs_for_account(conn, %{
        "account" => account,
        "limit" => limit,
        "page" => page,
        "txtype" => type
      }) do
    type = Util.to_tx_type(type)

    case :aeser_api_encoder.safe_decode(:account_pubkey, account) do
      {:ok, pk} ->
        json(conn, get_txs(limit, page, pk, type))

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid public key"})
    end
  end

  def txs_for_account(conn, %{"account" => account, "limit" => limit, "page" => page}) do
    case :aeser_api_encoder.safe_decode(:account_pubkey, account) do
      {:ok, pk} ->
        json(conn, get_txs(limit, page, pk))

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{"reason" => "Invalid public key"})
    end
  end

  # TODO! Work for: :spend_tx, :name_preclaim_tx, :name_claim_tx, :name_transfer_tx, :name_revoke_tx
  # TODO! Currently there is a problem with :name_transfer_tx and :name_revoke_tx, because of StreamSplit bug
  # TODO!!! check for :name_claim_tx - field name_fee: :prelima
  # Model.to_map is NOT working for:
  # 1. :name_update_tx -
  #                tx: %{
  #                  account_id: "ak_2WZoa13VKHCamt2zL9Wid8ovmyvTEUzqBjDNGDNwuqwUQJZG4t",
  #                  client_ttl: 36000,
  #                  fee: 20000,
  #                  name_id: "nm_6BcWWon9qDfFxyeoqCVzKnfqMnjSxerKBhfkUhSMf3LRAg2gJ",
  #                  name_ttl: 36000,
  #                  nonce: 363,
  #                  pointers: [                            !!! is not in right format !!!
  #                    {:pointer, "account_pubkey",
  #                     {:id, :account,
  #                      <<198, 212, 13, 163, 124, 167, 118, 43, 66, 61, 54, 12, 73, 234, 122,
  #                        234, 91, 231, 186, 128, ...>>}}
  #                  ],
  #                  ttl: 16700,
  #                  type: "NameUpdateTx"
  #                }
  # 2. :oracle_register_tx -
  #              tx: %{
  #                abi_version: 1,
  #                account_id: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
  #                fee: 30000,
  #                nonce: 18524,
  #                oracle_ttl: {:delta, 1800},       !!! is not in right format !!!
  #                query_fee: 500000,
  #                query_format: "string",
  #                response_format: "string",
  #                ttl: 50000,
  #                type: "OracleRegisterTx"
  #              }
  # 3. :oracle_query_tx -
  #             tx: %{
  #               fee: 600000000000000,
  #               nonce: 19060,
  #               oracle_id: "ok_28QDg7fkF5qiKueSdUvUBtCYPJdmMEoS73CztzXCRAwMGKHKZh",
  #               query: "ae_usdt",
  #               query_fee: 600000,
  #               query_ttl: {:delta, 100},     !!! is not in right format !!!
  #               response_ttl: {:delta, 3},    !!! is not in right format !!!
  #               sender_id: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
  #               ttl: 44336,
  #               type: "OracleQueryTx"
  #             }
  # 4. :oracle_response_tx -
  #               tx: %{
  #                 fee: 30000000000000,
  #                 nonce: 622,
  #                 oracle_id: "ok_28QDg7fkF5qiKueSdUvUBtCYPJdmMEoS73CztzXCRAwMGKHKZh",
  #                 query_id: <<241, 234, 224, 240, 75, 139, 168, 243, 136, 208, 38, 228, 62,
  #                   8, 28, 206, 249, 208, 95, 90, 89, 41, 122, 88, 152, 134, 58, 100, 7, 81,
  #                   86, 202>>,
  #                 response: "eyJsYXN0IjoiMC40MTc1IiwicmVzdWx0IjoidHJ1ZSIsImxvdzI0aHIiOiIwLjQwMjQiLCJoaWdoMjRociI6IjAuNDQ4NSIsImxvd2VzdEFzayI6IjAuNDE3NCIsImJhc2VWb2x1bWUiOiIxMjk4MTE3LjQ5MjU0Mjk1IiwiaGlnaGVzdEJpZCI6IjAuNDE0MyIsInF1b3RlVm9sdW1lIjoiMzA2ODM0Ny4yODM0NDY0MSIsInBlcmNlbnRDaGFuZ2UiOiItNi40MyIsInRpbWVzdGFtcCI6IjE1NTE3MDg4NTgiLCJkYXRhc291cmNlIjoiZ2F0ZS5pbyJ9",
  #                 response_ttl: {:delta, 3},    !!! is not in right format !!!
  #                 ttl: 46498,
  #                 type: "OracleResponseTx"
  #               },
  #               tx_index: 1223111,
  #               tx_type: :oracle_response_tx
  #             }
  # 5. :name_update_tx -
  #            tx: %{
  #              account_id: "ak_2TJ5XkWq7UXVvaJNHertv59pPGzvXRX1J7nc1Zh1Q2SFsY6fwr",
  #              client_ttl: 36000,
  #              fee: 20000000000000,
  #              name_id: "nm_oMp9D2dtfj9h6EQezeKPHQhev1AE23fH3Ye6vz9j8cP4bQWCx",
  #              name_ttl: 50000,
  #              nonce: 3634,
  #              pointers: [           !!! is not in right format !!!
  #                {:pointer, "account_pubkey",
  #                 {:id, :account,
  #                  <<53, 55, 180, 211, 41, 147, 10, 247, 24, 35, 151, 47, 125, 174, 118,
  #                    243, 155, 15, 227, 96, ...>>}}
  #              ],
  #              ttl: 60000,
  #              type: "NameUpdateTx"
  #            }
  #   tx: %{
  #   6. :contract_call_tx -   (Jason.EncodeError) invalid byte 0x9F in <<0, 0,..>>
  #           tx: %{
  #             abi_version: 1,
  #             amount: 0,
  #             call_data: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  #               0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...>>,
  #             call_origin: <<140, 45, 15, 171, 198, 112, 76, 122, 188, 218, 79, 0, 14,
  #               175, 238, 64, 9, 82, 93, 44, 169, 176, 237, 27, 115, 221, 101, 211, 5,
  #               168, ...>>,
  #             call_stack: [],
  #             caller_id: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
  #             contract_id: "ct_26idsmrCmVz2s3ZhXmhmmBtNA8Xz6hb9b4h3kUNSEDw5eCVkYG",
  #             fee: 2034140000000000,
  #             gas: 1579000,
  #             gas_price: 1000000000,
  #             nonce: 19147,
  #             ttl: 0,
  #             type: "ContractCallTx"
  #           },
  #           tx_index: 1415245,
  #           tx_type: :contract_call_tx
  #         }
  # 7. :channel_create_tx -  !!! the problem is in `state_hash`!!!
  #          tx: %{
  #            channel_reserve: 2,
  #            delegate_ids: [],
  #            fee: 20000,
  #            initiator_amount: 70000,
  #            initiator_id: "ak_28QDg7fkF5qiKueSdUvUBtCYPJdmMEoS73CztzXCRAwMGKHKZh",
  #            lock_period: 1,
  #            nonce: 103,
  #            responder_amount: 40000,
  #            responder_id: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
  #            state_hash: <<189, 115, 46, 77, 245, 48, 95, 58, 158, 84, 178, 221, 173,
  #              160, 40, 200, 252, 186, 172, 74, 57, 131, 131, 201, ...>>,
  #            ttl: 0,
  #            type: "ChannelCreateTx"
  #          },
  #          tx_index: 610680,
  #          tx_type: :channel_create_tx
  #        }
  def txs_for_interval(conn, %{"limit" => limit, "page" => page, "txtype" => type}) do
    type = Util.to_tx_type(type)
    json(conn, %{"transactions" => get_txs(limit, page, type)})
  end

  def txs_for_interval(conn, %{"limit" => limit, "page" => page}) do
    json(conn, %{"transactions" => get_txs(limit, page)})
  end

  defp get_txs(limit, page) do
    limit = String.to_integer(limit)
    page = String.to_integer(page)

    limit
    |> Util.pagination(page, [], DBSTx.rev_tx())
    |> List.first()
    |> Enum.map(&Model.to_map/1)
  end

  defp get_txs(limit, page, pk, type) do
    limit = String.to_integer(limit)
    page = String.to_integer(page)

    data =
      pk
      |> DBS.Object.rev_tx()
      |> Stream.map(&Model.to_map/1)
      |> Stream.filter(fn tx -> tx.tx_type == type end)

    limit
    |> Util.pagination(page, [], data)
    |> List.first()
  end

  defp get_txs(limit, page, data) do
    limit = String.to_integer(limit)
    page = String.to_integer(page)

    limit
    |> Util.pagination(page, [], exec(data))
    |> List.first()
    |> Enum.map(&Model.to_map/1)
  end

  defp exec(data) when is_binary(data), do: DBS.Object.rev_tx(data)
  defp exec(data) when is_atom(data), do: DBS.Type.rev_tx(data)
end
