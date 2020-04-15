defmodule AeMdwWeb.ChannelController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  # Hardcoded DB only for testing purpose
  @active_channels [
    "ch_2tceSwiqxgBcPirX3VYgW3sXgQdJeHjrNWHhLWyfZL7pT4gZF4",
    "ch_AG5wzf4F9nMyuAmPav981Dk2XiQhAFvWAiNbUniZNPvk1qZxa",
    "ch_DhA1FvZ2vcN9waEUmTcztPbjYH8aJ6FcKiLEUg5xWYbm9ktSU",
    "ch_2KP1gKWTgFxmPWpQDWr1Gbghi18ZtxPMFELqhEQ651B2a5ZtXi",
    "ch_2jAjhyQ4kTpuJbANBDMWtdsaDyFjAaAEmoVFmuFvKXnZLvt7hn",
    "ch_284sMWGcDzkf6LGbZVkNwmt2rieeLdPtSJCtVd7QQpTuoZHMkQ"
  ]

  @channel_tx %{
    "transactions" => [
      %{
        "block_height" => 9155,
        "block_hash" => "mh_2C1TrRnqvc8tAyeRpj6YWeuZHCgST1p5uackmJJ5VdyP3rrGMT",
        "hash" => "th_2fp28uzrnS2kiGddAHpTnkVJ4MtRapoJzEJbCojDznvTwvNdo8",
        "signatures" => [
          "sg_ADWpdrNBXGX9f245Pu8RLDQ5AeRQCiw8UyUrQKoFMkvgUSULNuZPAAo1tvfhyusRgHKtW5Q92hzoqj1MZcVH4ub7dswJy",
          "sg_LRsP3UzUnUb4TtXqPDmUmQsb2aB1GUV8g3JMF4mWpfcChtBuyGtbzFpJfTYkKpvMEpc6AMJM156bCr24BNtUk75NNGJLK"
        ],
        "tx" => %{
          "channel_reserve" => 2,
          "delegate_ids" => [],
          "fee" => 20000,
          "initiator_amount" => 10,
          "initiator_id" => "ak_2VsncWAk9qkA8SAY8zpcympSaCN313TV9GjAPZ9XQUFMSz4vTf",
          "lock_period" => 10,
          "nonce" => 2,
          "responder_amount" => 10,
          "responder_id" => "ak_25UPgAhVxTrq6CCyjDYhMpPadW6QLHNxtV5a2je12RGk1Rfmjt",
          "state_hash" => "st_AkEG+wvKWZdW9R+Zzz+7HHTTR3KWcTNrQNpGMr/VmR3DqtiC",
          "type" => "ChannelCreateTx",
          "version" => 1
        }
      }
    ]
  }

  swagger_path :active_channels do
    get("/channels/active")
    description("Get Active Channel Names")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_active_channels")
    response(200, "", %{})
  end

  def active_channels(conn, _params) do
    json(conn, @active_channels)
  end

  swagger_path :channel_tx do
    get("/channels/transactions/address/{address}")
    description("Get all transactions for a state channel")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_channel_tx")

    parameters do
      address(:path, :string, "", required: true)
    end

    response(200, "", %{})
  end

  def channel_tx(conn, _params) do
    json(conn, @channel_tx)
  end
end
