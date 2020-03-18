defmodule AeMdwWeb.TransactionController do
  use AeMdwWeb, :controller

  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Db.Stream.Tx, as: DBSTx
  alias AeMdwWeb.Util
  require Model

  # Hardcoded DB only for testing purpose
  @txs_count_for_account %{
    "count" => 5
  }

  @txs_for_account [
    %{
      "block_hash" => "mh_z6gWrigkBuH6c6jRF2b9spaX4gABbD9Ygv3W3KXmbwyzmRyg9",
      "block_height" => 218_464,
      "hash" => "th_2pfaFwvkky264xH5F7co2RLk4rdf5myUd3JDWS7ipB7xeqpFAF",
      "signatures" => [
        "sg_YecgqoepEVvVbZxAE6a9vgZh8qFCAE6WgfGhJ4BwnN8m1t3MPtmcYB2zQ3Z2qRYcMFoHJqLEENp9LrQPhmbfS6UuCcLqM"
      ],
      "time" => 1_582_811_950_673,
      "tx" => %{
        "amount" => 2.0322363e+21,
        "fee" => 16_840_000_000_000,
        "nonce" => 69,
        "payload" => "ba_Xfbg4g==",
        "recipient_id" => "ak_S5JTasvPZsbYWbEUFNsme8vz5tqkdhtGx3m7yJC7Dpqi4rS2A",
        "sender_id" => "ak_2krkF8Sfg9qEFQTLEaa8XkqwaY4rzYjFGsqbf5ptxabFoj5awH",
        "type" => "SpendTx",
        "version" => 1
      }
    },
    %{
      "block_hash" => "mh_z6gWrigkBuH6c6jRF2b9spaX4gABbD9Ygv3W3KXmbwyzmRyg9",
      "block_height" => 218_464,
      "hash" => "th_2pfaFwvkky264xH5F7co2RLk4rdf5myUd3JDWS7ipB7xeqpFAF",
      "signatures" => [
        "sg_YecgqoepEVvVbZxAE6a9vgZh8qFCAE6WgfGhJ4BwnN8m1t3MPtmcYB2zQ3Z2qRYcMFoHJqLEENp9LrQPhmbfS6UuCcLqM"
      ],
      "time" => 1_582_811_950_673,
      "tx" => %{
        "amount" => 2.0322363e+21,
        "fee" => 16_840_000_000_000,
        "nonce" => 69,
        "payload" => "ba_Xfbg4g==",
        "recipient_id" => "ak_S5JTasvPZsbYWbEUFNsme8vz5tqkdhtGx3m7yJC7Dpqi4rS2A",
        "sender_id" => "ak_2krkF8Sfg9qEFQTLEaa8XkqwaY4rzYjFGsqbf5ptxabFoj5awH",
        "type" => "SpendTx",
        "version" => 1
      }
    }
  ]

  # looks like it is not working in aeternal
  @txs_for_interval %{
    "transactions" => [
      %{
        "block_height" => 226_186,
        "block_hash" => "mh_298WTFdAnefHAMBacmUD9EfoaLZG81D1BFmiSZpN4Ep7F4CwEf",
        "hash" => "th_28G8aE47RbGQ48iVqEkxnVEZHNSteD1zbczkLEkLTuGrmgT51E",
        "signatures" => [
          "sg_6E1Pg8LF6ER5z2mXJqJjBDH4nCznxp1aBHNFqPoVw5anBw4hmLuuT2bTVbC8wukmx5xKLS9TL2CRJpVTYoSgdkg8qYFAJ"
        ],
        "tx" => %{
          "amount" => 20000,
          "fee" => 19_320_000_000_000,
          "nonce" => 1_578_556,
          "payload" =>
            "ba_MjI2MTg2OmtoX25tdnM2VVBqNnBtcnl6ckhBV0dvd281S041dkVjVkEyblRFeDZGYXk3VjJlOVNkR1Y6bWhfMnJ4SmFxYVJRVDdORzQxMXFTTFh4VUNuUGZHU2lvYUtBUXBUblkyUHV6cHRGRUtpaWg6MTU4NDIxMDcxNy1crBU=",
          "recipient_id" => "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR",
          "sender_id" => "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR",
          "ttl" => 226_196,
          "type" => "SpendTx",
          "version" => 1
        }
      },
      %{
        "block_height" => 226_186,
        "block_hash" => "mh_298WTFdAnefHAMBacmUD9EfoaLZG81D1BFmiSZpN4Ep7F4CwEf",
        "hash" => "th_NXd4ZLvJ9VwSki9GMDcParjJyeVuFVFzJM55CqiyLsBXqMD2D",
        "signatures" => [
          "sg_4NL4hVxSR96bMwm3oeDwHRNLtQCpW924ABCNnBtPj6RX4QdmpMSFPdrjU38a6WknSmCpvQreF7AEiVVh6iEcjvDjzz3KN"
        ],
        "tx" => %{
          "amount" => 20000,
          "fee" => 19_320_000_000_000,
          "nonce" => 1_580_392,
          "payload" =>
            "ba_MjI2MTg2OmtoX25tdnM2VVBqNnBtcnl6ckhBV0dvd281S041dkVjVkEyblRFeDZGYXk3VjJlOVNkR1Y6bWhfMnJ4SmFxYVJRVDdORzQxMXFTTFh4VUNuUGZHU2lvYUtBUXBUblkyUHV6cHRGRUtpaWg6MTU4NDIxMDcxNjsygD8=",
          "recipient_id" => "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd",
          "sender_id" => "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd",
          "ttl" => 226_196,
          "type" => "SpendTx",
          "version" => 1
        }
      }
    ]
  }

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

  def txs_count_for_account(conn, _params) do
    json(conn, @txs_count_for_account)
  end

  def txs_for_account_to_account(conn, _params) do
    json(conn, @txs_for_account_to_account)
  end

  def txs_for_account(conn, _params) do
    json(conn, @txs_for_account)
  end

  def tx_rate(conn, _params) do
    json(conn, @tx_rate)
  end

  # TODO! Work for: :spend_tx, :name_preclaim_tx, :name_claim_tx, :name_transfer_tx, :name_revoke_tx
  # TODO! Currently there is problem with :name_transfer_tx and :name_revoke_tx, because of StreamSplit bug
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
  def txs_for_interval(conn, %{"limit" => limit, "page" => page, "txtype" => type}) do
    type = AeMdwWeb.Util.to_tx_type(type)
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

  defp get_txs(limit, page, type) do
    limit = String.to_integer(limit)
    page = String.to_integer(page)

    limit
    |> Util.pagination(page, [], DBS.Type.rev_tx(type))
    |> List.first()
    |> Enum.map(&Model.to_map/1)
  end
end
