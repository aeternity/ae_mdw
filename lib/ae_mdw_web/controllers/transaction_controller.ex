defmodule AeMdwWeb.TransactionController do
  use AeMdwWeb, :controller

  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Db.Stream.Tx, as: DBSTx
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

  def txs_for_interval(conn, _params) do
    json(conn, @txs_for_interval)
  end

  def tx_rate(conn, _params) do
    json(conn, @tx_rate)
  end
end
