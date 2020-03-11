defmodule AeMdwWeb.TransactionController do
  use AeMdwWeb, :controller

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
    }
  ]

  # looks like it is not working in aeternal
  @txs_for_interval []

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

  def txs_for_interval(conn, _params) do
    json(conn, @txs_for_interval)
  end

  def tx_rate(conn, _params) do
    json(conn, @tx_rate)
  end
end
