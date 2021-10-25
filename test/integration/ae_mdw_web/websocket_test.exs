defmodule AeMdwWeb.WebsocketTest do
  use ExUnit.Case

  alias AeMdwWeb.Websocket.ChainListener
  alias Support.WsClient

  @moduletag :integration

  setup_all do
    url = "ws://localhost:4001/websocket"
    {:ok, client1} = WsClient.start_link(url)
    {:ok, client2} = WsClient.start_link(url)
    {:ok, client3} = WsClient.start_link(url)
    {:ok, client4} = WsClient.start_link(url)

    mock_kb = %{
      "payload" => %{
        "beneficiary" => "ak_2ceZWyHKEaXrufdA3aTvV3fbJop3JQhKQJi62Fpv4RcAG5DYUu",
        "hash" => "kh_263kFEmsCR7oxrWkKmJm37DgNtHcJDC1tJeuq9F7WLyr7LpvqB",
        "height" => 258_046,
        "info" => "cb_AAACHMKhM24=",
        "miner" => "ak_EYJcCSaD21hTogGXa1agdLfqogb2gy1gL2C51GSMHA8MiJanB",
        "nonce" => 315_913_740_866_945_046,
        "pow" => [
          6_993_960,
          31_153_581,
          67_687_798,
          68_102_823,
          80_522_467,
          85_604_801,
          87_141_884,
          94_986_399,
          101_375_201,
          131_500_950,
          164_817_799,
          170_104_234,
          180_270_885,
          198_794_827,
          239_686_867,
          240_088_077,
          252_204_944,
          252_395_596,
          275_356_981,
          283_346_685,
          306_588_887,
          320_345_496,
          327_277_344,
          348_721_612,
          398_989_548,
          404_560_393,
          407_442_618,
          416_306_045,
          436_348_048,
          447_591_338,
          449_683_239,
          451_993_748,
          455_143_367,
          460_547_805,
          462_870_997,
          475_397_198,
          488_547_495,
          497_626_608,
          500_735_838,
          503_795_310,
          508_333_349,
          526_021_468
        ],
        "prev_hash" => "mh_gBCGkRbnsHKpK5Kf3eCLF2MZYCKXPWdUFR2XuVVJ8W6uo1Vnj",
        "prev_key_hash" => "kh_23YnsDHBdvKDg3gNxmZT9YJe1Vd3WkUbMZg3SuNY3DR6h9V4qV",
        "state_hash" => "bs_2qQjLXpyjF9Bu7FJhZh4LD8QnQZqfu2aZ3nfDuUuKuz7FqGNN3",
        "target" => 505_889_148,
        "time" => 1_589_979_942_256,
        "version" => 4
      },
      "subscription" => "KeyBlocks"
    }

    mock_mb = %{
      "payload" => %{
        "hash" => "mh_Jh1fPrNNUbWPsXPugCdZ7RRHBwptu1UzzWwU7N6iRKBHjnv3z",
        "height" => 256_371,
        "pof_hash" => "no_fraud",
        "prev_hash" => "mh_2Pw9bhi9xzNv3tBo7HSELRezp4niQ6odYxPFCAhtRwiycUDyjB",
        "prev_key_hash" => "kh_g3oqQ5DnMUxVAe3onDU6qUmNZfYurxkLcDDdXjQtQhkyTsmHy",
        "signature" =>
          "sg_4xEM776i5NAiMkL7FcPtfmLWhjRDCjnPXqWhyuobBptdpVpuRQZAqVwGvHnDW9gQ1EWah1ctNckPvW1mi8ch4XB4ndzxH",
        "state_hash" => "bs_2djdLDNsrkxVSJP3Sxcxa5fPYRkd4ujfB2Gh9Fd5hnu4re8qnh",
        "time" => 1_589_677_605_998,
        "txs_hash" => "bx_2PWfRBMf9vfZ6HeSmpuVVdDe481kqJA29o32DT52esd7fhZEpV",
        "version" => 4
      },
      "subscription" => "MicroBlocks"
    }

    mock_tx = %{
      "payload" => %{
        "block_hash" => "mh_Jh1fPrNNUbWPsXPugCdZ7RRHBwptu1UzzWwU7N6iRKBHjnv3z",
        "block_height" => 256_371,
        "hash" => "th_XCzs29JhAh7Jpd5fypNi42Kszc4eVYEadw62cNBc7qBHajhD7",
        "signatures" => [
          "sg_6fpktydrCQLxtcG5beP8Z6SS2ZbTcLxiKjZz48hYtKrNC3Aurocvt6xpTv199PV8t39N2v34TP9a8Kb2Rt9VJ2sEKD8ZU"
        ],
        "tx" => %{
          "amount" => 20000,
          "fee" => 19_320_000_000_000,
          "nonce" => 2_118_032,
          "payload" =>
            "ba_MjU2MzcxOmtoX2czb3FRNURuTVV4VkFlM29uRFU2cVVtTlpmWXVyeGtMY0REZFhqUXRRaGt5VHNtSHk6bWhfMlB3OWJoaTl4ek52M3RCbzdIU0VMUmV6cDRuaVE2b2RZeFBGQ0FodFJ3aXljVUR5akI6MTU4OTY3NzYwNjNjn60=",
          "recipient_id" => "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs",
          "sender_id" => "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs",
          "ttl" => 256_381,
          "type" => "SpendTx",
          "version" => 1
        }
      },
      "subscription" => "Transactions"
    }

    mock_obj = %{
      "payload" => %{
        "block_hash" => "mh_Jh1fPrNNUbWPsXPugCdZ7RRHBwptu1UzzWwU7N6iRKBHjnv3z",
        "block_height" => 256_371,
        "hash" => "th_XCzs29JhAh7Jpd5fypNi42Kszc4eVYEadw62cNBc7qBHajhD7",
        "signatures" => [
          "sg_6fpktydrCQLxtcG5beP8Z6SS2ZbTcLxiKjZz48hYtKrNC3Aurocvt6xpTv199PV8t39N2v34TP9a8Kb2Rt9VJ2sEKD8ZU"
        ],
        "tx" => %{
          "amount" => 20000,
          "fee" => 19_320_000_000_000,
          "nonce" => 2_118_032,
          "payload" =>
            "ba_MjU2MzcxOmtoX2czb3FRNURuTVV4VkFlM29uRFU2cVVtTlpmWXVyeGtMY0REZFhqUXRRaGt5VHNtSHk6bWhfMlB3OWJoaTl4ek52M3RCbzdIU0VMUmV6cDRuaVE2b2RZeFBGQ0FodFJ3aXljVUR5akI6MTU4OTY3NzYwNjNjn60=",
          "recipient_id" => "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs",
          "sender_id" => "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs",
          "ttl" => 256_381,
          "type" => "SpendTx",
          "version" => 1
        }
      },
      "subscription" => "Object"
    }

    mock_info_mb = %{
      block_hash:
        <<40, 42, 190, 188, 145, 183, 19, 141, 46, 90, 107, 73, 97, 202, 37, 9, 136, 233, 17, 65,
          19, 77, 129, 103, 158, 211, 247, 227, 69, 108, 91, 127>>,
      block_type: :micro,
      height: 256_371,
      prev_hash:
        <<183, 197, 5, 175, 74, 228, 116, 98, 103, 166, 42, 238, 253, 154, 79, 146, 116, 9, 43, 0,
          107, 47, 185, 25, 39, 32, 69, 235, 55, 32, 171, 207>>
    }

    mock_info_kb = %{
      block_hash:
        <<143, 40, 29, 25, 19, 209, 104, 75, 29, 15, 98, 58, 79, 81, 40, 18, 226, 109, 129, 161,
          122, 242, 115, 163, 48, 4, 22, 107, 71, 131, 21, 55>>,
      block_type: :key,
      height: 258_046,
      prev_hash:
        <<88, 244, 15, 196, 237, 115, 149, 52, 57, 25, 239, 219, 106, 82, 83, 34, 129, 98, 114,
          120, 49, 206, 255, 6, 70, 117, 8, 137, 179, 220, 29, 33>>
    }

    [
      client1: client1,
      client2: client2,
      client3: client3,
      client4: client4,
      mock_info_mb: mock_info_mb,
      mock_info_kb: mock_info_kb,
      mock_kb: mock_kb,
      mock_mb: mock_mb,
      mock_tx: mock_tx,
      mock_obj: mock_obj
    ]
  end

  test "subscribe and unsubscribe to keyblocks, microblocks, transactions and object", setup do
    # subscribe to keyblocks, microblocks, transactions and object
    assert :ok == WsClient.subscribe(setup.client1, :key_blocks)
    assert :ok == WsClient.subscribe(setup.client2, :micro_blocks)
    assert :ok == WsClient.subscribe(setup.client3, :transactions)

    assert :ok ==
             WsClient.subscribe(
               setup.client4,
               "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs"
             )

    # send mock info to listener
    send(ChainListener, {:gproc_ps_event, :top_changed, %{info: setup.mock_info_mb}})
    send(ChainListener, {:gproc_ps_event, :top_changed, %{info: setup.mock_info_kb}})

    # send request to ws client
    Process.send_after(setup.client1, {:subs, self()}, 100)
    Process.send_after(setup.client2, {:subs, self()}, 100)
    Process.send_after(setup.client3, {:subs, self()}, 100)
    Process.send_after(setup.client4, {:subs, self()}, 100)

    Process.send_after(setup.client1, {:kb, self()}, 100)
    Process.send_after(setup.client2, {:mb, self()}, 100)
    Process.send_after(setup.client3, {:tx, self()}, 100)
    Process.send_after(setup.client4, {:obj, self()}, 100)

    mock_kb = setup.mock_kb
    mock_mb = setup.mock_mb
    mock_tx = setup.mock_tx
    mock_obj = setup.mock_obj

    # assert incoming data
    assert_receive ["Transactions"], 200
    assert_receive ["KeyBlocks"], 200
    assert_receive ["MicroBlocks"], 200
    assert_receive ["ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs"], 200

    assert_receive ^mock_kb, 300
    assert_receive ^mock_mb, 300
    assert_receive ^mock_tx, 300
    assert_receive ^mock_obj, 300

    # unsubscribe to keyblocks, microblocks, transactions and object
    assert :ok == WsClient.unsubscribe(setup.client1, :key_blocks)
    assert :ok == WsClient.unsubscribe(setup.client2, :micro_blocks)
    assert :ok == WsClient.unsubscribe(setup.client3, :transactions)

    assert :ok ==
             WsClient.unsubscribe(
               setup.client4,
               "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs"
             )

    # send request to ws client
    Process.send_after(setup.client1, {:subs, self()}, 100)
    Process.send_after(setup.client2, {:subs, self()}, 100)
    Process.send_after(setup.client3, {:subs, self()}, 100)
    Process.send_after(setup.client4, {:subs, self()}, 100)

    # assert incoming data
    assert_receive [], 200
    assert_receive [], 200
    assert_receive [], 200
    assert_receive [], 200
  end

  test "subscribe to unsupported payload and invalid targets", setup do
    # subscribe to unsupported payload and invalid targets
    assert :ok == WsClient.subscribe(setup.client1, :unsupported_payload)
    assert :ok == WsClient.subscribe(setup.client2, "invalid target")
    assert :ok == WsClient.subscribe(setup.client3, "ak_1234")
    assert :ok == WsClient.subscribe(setup.client4, :object)

    # send request to ws client
    Process.send_after(setup.client1, {:error, self()}, 50)
    Process.send_after(setup.client2, {:error, self()}, 50)
    Process.send_after(setup.client3, {:error, self()}, 50)
    Process.send_after(setup.client4, {:error, self()}, 50)

    # assert incoming data
    assert_receive "invalid payload: UnsupportedPayload"
    assert_receive "invalid target: invalid target"
    assert_receive "invalid target: ak_1234"
    assert_receive "requires target"
  end
end
