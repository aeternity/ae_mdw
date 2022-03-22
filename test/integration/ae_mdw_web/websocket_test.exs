defmodule Integration.AeMdwWeb.WebsocketTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Util
  alias AeMdwWeb.Websocket.Broadcaster
  alias AeMdwWeb.Websocket.ChainListener
  alias Support.WsClient

  import AeMdw.Db.Util, only: [read_block!: 1]

  require Model

  @moduletag :integration

  @key_block_mdw %{
    "payload" => %{
      "beneficiary" => "ak_dArxCkAsk1mZB1L9CX3cdz1GDN4hN84L3Q8dMLHN4v8cU85TF",
      "hash" => "kh_2RXxu2sroGxiTu3wTR37WyksWNbn3a5aiCmYe1uri5wv4xmYWE",
      "height" => 311_860,
      "info" => "cb_AAACKimwwOc=",
      "miner" => "ak_2CzSdjhz7sAthzMyHoCs8NBboBsgpJ8Mznve6UMovKAzjJ9y3w",
      "nonce" => 55_834_707_426,
      "pow" => [
        1_892_152,
        2_255_008,
        8_301_731,
        9_372_185,
        38_096_107,
        56_693_111,
        94_946_898,
        97_590_005,
        98_590_929,
        100_181_836,
        110_476_606,
        113_616_192,
        115_821_589,
        129_755_731,
        130_820_095,
        139_501_760,
        140_474_719,
        165_229_856,
        184_620_399,
        186_210_732,
        189_993_725,
        203_330_224,
        214_315_153,
        219_177_032,
        246_205_502,
        255_420_064,
        263_152_354,
        275_152_470,
        294_724_058,
        305_334_908,
        306_022_580,
        331_751_672,
        352_549_376,
        365_451_580,
        368_518_509,
        381_374_206,
        397_903_495,
        400_847_079,
        416_608_085,
        417_690_484,
        467_186_896,
        527_658_673
      ],
      "prev_hash" => "mh_b7Mwr7rQqVxczb7Zy6kgjQQrW9PnNn8M66EzHtZ5wpiEBCqk7",
      "prev_key_hash" => "kh_tZbZxULQNnxrfRmSRoq1MMSPNMyMgKK3rBe2VviTARr63LSne",
      "state_hash" => "bs_5yRx3yNE1NUso68VENdyxJfrYTfLTES3NFm9rgXY5NpaKNVWD",
      "target" => 508_403_744,
      "time" => 1_599_724_312_115,
      "version" => 4
    },
    "source" => "mdw",
    "subscription" => "KeyBlocks"
  }

  @micro_block_mdw %{
    "payload" => %{
      "hash" => "mh_knNmfDwU9jhtXkszNCCr28iPtRa4Cd9RCTs54izr2QMLWWyk9",
      "height" => 311_860,
      "pof_hash" => "no_fraud",
      "prev_hash" => "kh_2RXxu2sroGxiTu3wTR37WyksWNbn3a5aiCmYe1uri5wv4xmYWE",
      "prev_key_hash" => "kh_2RXxu2sroGxiTu3wTR37WyksWNbn3a5aiCmYe1uri5wv4xmYWE",
      "signature" =>
        "sg_QVegH83hN8pwag22zLdLJmBPUC6sP1JnNmGhnrURBBY3gVWXjorbJTCPUsg4hR78eF1fS1Jy8pNH56nsmib4nQbdvx3Xj",
      "state_hash" => "bs_UcVHoHqKaz4MN61Wp2vaXXJBH3cjkyLvoCD4aQKnQSYzxLXZo",
      "time" => 1_599_724_809_752,
      "txs_hash" => "bx_BcnyCFr7yx1NQmrqwaTSXctVo28ZRjTtBfgeXjght2WZaNCkA",
      "version" => 4
    },
    "source" => "mdw",
    "subscription" => "MicroBlocks"
  }

  @transaction_mdw %{
    "payload" => %{
      "block_hash" => "mh_knNmfDwU9jhtXkszNCCr28iPtRa4Cd9RCTs54izr2QMLWWyk9",
      "block_height" => 311_860,
      "hash" => "th_VyepHVU43zbytTihQprS689bbq9pYcHkW9iw7GZnUGmaf8N5o",
      "signatures" => [
        "sg_141SJQyyzetSW29HKAX8Tp5mci8cNWsfZesAMKY8vD2ZFGjnGzM2jVXsDFMgbvXrUEeTEhwTpXQzdyK79LvmR4B3ZENXg"
      ],
      "tx" => %{
        "amount" => 24_570_952_900_000_000_000,
        "fee" => 16_880_000_000_000,
        "nonce" => 463,
        "payload" => "ba_Xfbg4g==",
        "recipient_id" => "ak_dnzaNnchT7f3YT3CtrQ7GUjqGT6VaHzPxpf2efHWPuEAWKcht",
        "sender_id" => "ak_2hTDeNjj9zz2PV3JfdnqGwLTERDwmhmL3WfhzPqCKFr4kZvPH1",
        "type" => "SpendTx",
        "version" => 1
      }
    },
    "source" => "mdw",
    "subscription" => "Transactions"
  }

  @object_mdw %{
    "payload" => %{
      "block_hash" => "mh_knNmfDwU9jhtXkszNCCr28iPtRa4Cd9RCTs54izr2QMLWWyk9",
      "block_height" => 311_860,
      "hash" => "th_2KYycJjNrL4htFhwCVrKnx3nazdzZ3Vu4XPRhoqMpvTB5SGK4Q",
      "signatures" => [
        "sg_RZegs6ZPiYrsDWg8nLrbrrZAYZV9pCMtkamzVgjLGhSVNZHM7cfNudwN41QWTy1KVMqWNi8xujuxCDGAtdSAs2osV6yQ7"
      ],
      "tx" => %{
        "amount" => 20000,
        "fee" => 19_300_000_000_000,
        "nonce" => 3_097_160,
        "payload" =>
          "ba_MzExODU5OmtoX3RaYlp4VUxRTm54cmZSbVNSb3ExTU1TUE5NeU1nS0szckJlMlZ2aVRBUnI2M0xTbmU6bWhfUHNwYlV6RVQ5TlRjRW1odGc3OFBvVmVQakVzMkdqdllqNmpxQUNvNkIxVHJUNkI4WjoxNTk5NzI0NTMy+8t8tw==",
        "recipient_id" => "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd",
        "sender_id" => "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd",
        "ttl" => 311_869,
        "type" => "SpendTx",
        "version" => 1
      }
    },
    "source" => "mdw",
    "subscription" => "Object"
  }

  setup_all do
    url = "ws://localhost:4001/websocket"
    clients = for _i <- 1..8, do: url |> WsClient.start_link() |> Util.ok!()

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
      "subscription" => "KeyBlocks",
      "source" => "node"
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
      "subscription" => "MicroBlocks",
      "source" => "node"
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
      "subscription" => "Transactions",
      "source" => "node"
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
      "subscription" => "Object",
      "source" => "node"
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
      clients: clients,
      mock_info_mb: mock_info_mb,
      mock_info_kb: mock_info_kb,
      mock_kb: mock_kb,
      mock_mb: mock_mb,
      mock_tx: mock_tx,
      mock_obj: mock_obj
    ]
  end

  test "subscribe and unsubscribe to keyblocks, microblocks, transactions and object", %{
    clients: [client1, client2, client3, client4 | _other_case],
    mock_info_mb: mock_info_mb,
    mock_info_kb: mock_info_kb,
    mock_kb: mock_kb,
    mock_mb: mock_mb,
    mock_tx: mock_tx,
    mock_obj: mock_obj
  } do
    # subscribe to keyblocks, microblocks, transactions and object
    assert :ok == WsClient.subscribe(client1, :key_blocks)
    assert :ok == WsClient.subscribe(client2, :micro_blocks)
    assert :ok == WsClient.subscribe(client3, :transactions)

    assert :ok ==
             WsClient.subscribe(
               client4,
               "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs"
             )

    # send mock info to listener
    send(ChainListener, {:gproc_ps_event, :top_changed, %{info: mock_info_mb}})
    send(ChainListener, {:gproc_ps_event, :top_changed, %{info: mock_info_kb}})

    # send request to ws client
    Process.send_after(client1, {:subs, self()}, 100)
    Process.send_after(client2, {:subs, self()}, 100)
    Process.send_after(client3, {:subs, self()}, 100)
    Process.send_after(client4, {:subs, self()}, 100)

    Process.send_after(client1, {:kb, self()}, 100)
    Process.send_after(client2, {:mb, self()}, 100)
    Process.send_after(client3, {:tx, self()}, 100)
    Process.send_after(client4, {:obj, self()}, 100)

    mock_kb = mock_kb
    mock_mb = mock_mb
    mock_tx = mock_tx
    mock_obj = mock_obj

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
    assert :ok == WsClient.unsubscribe(client1, :key_blocks)
    assert :ok == WsClient.unsubscribe(client2, :micro_blocks)
    assert :ok == WsClient.unsubscribe(client3, :transactions)

    assert :ok ==
             WsClient.unsubscribe(
               client4,
               "ak_KHfXhF2J6VBt3sUgFygdbpEkWi6AKBkr9jNKUCHbpwwagzHUs"
             )

    # send request to ws client
    Process.send_after(client1, {:subs, self()}, 100)
    Process.send_after(client2, {:subs, self()}, 100)
    Process.send_after(client3, {:subs, self()}, 100)
    Process.send_after(client4, {:subs, self()}, 100)

    # assert incoming data
    assert_receive [], 200
    assert_receive [], 200
    assert_receive [], 200
    assert_receive [], 200
  end

  test "subscribe to unsupported payload and invalid targets", %{
    clients: [client1, client2, client3, client4 | _other_case]
  } do
    # subscribe to unsupported payload and invalid targets
    assert :ok == WsClient.subscribe(client1, :unsupported_payload)
    assert :ok == WsClient.subscribe(client2, "invalid target")
    assert :ok == WsClient.subscribe(client3, "ak_1234")
    assert :ok == WsClient.subscribe(client4, :object)

    # send request to ws client
    Process.send_after(client1, {:error, self()}, 50)
    Process.send_after(client2, {:error, self()}, 50)
    Process.send_after(client3, {:error, self()}, 50)
    Process.send_after(client4, {:error, self()}, 50)

    # assert incoming data
    assert_receive "invalid payload: UnsupportedPayload"
    assert_receive "invalid target: invalid target"
    assert_receive "invalid target: ak_1234"
    assert_receive "requires target"
  end

  describe "notifications after mdw sync" do
    test "for keyblocks, microblocks, transactions and object", %{clients: clients} do
      [client1, client2, client3, client4] = Enum.drop(clients, 4)
      recipient_id = "ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd"

      assert :ok == WsClient.subscribe(client1, :key_blocks)
      assert :ok == WsClient.subscribe(client2, :micro_blocks)
      assert :ok == WsClient.subscribe(client3, :transactions)
      assert :ok == WsClient.subscribe(client4, recipient_id)

      # send request to ws client
      Process.send_after(client1, {:subs, self()}, 100)
      Process.send_after(client2, {:subs, self()}, 100)
      Process.send_after(client3, {:subs, self()}, 100)
      Process.send_after(client4, {:subs, self()}, 100)

      # assert subscriptions
      assert_receive ["Transactions"], 200
      assert_receive ["KeyBlocks"], 200
      assert_receive ["MicroBlocks"], 200
      assert_receive [^recipient_id], 200

      {key_block, micro_blocks} = get_blocks(311_860)
      Broadcaster.broadcast_key_block(key_block, :mdw)
      Process.send_after(client1, {:kb, self()}, 100)

      kb_payload = @key_block_mdw
      assert_receive ^kb_payload, 300

      [mb1 | _] = micro_blocks
      Broadcaster.broadcast_micro_block(mb1, :mdw)
      Process.send_after(client2, {:mb, self()}, 100)

      mb1_payload = @micro_block_mdw
      assert_receive ^mb1_payload, 300

      Broadcaster.broadcast_txs(mb1, :mdw)
      Process.send_after(client3, {:tx, self()}, 200)
      Process.send_after(client4, {:obj, self()}, 200)

      tx_payload = @transaction_mdw
      assert_receive ^tx_payload, 500

      obj_payload = @object_mdw
      assert_receive ^obj_payload, 500
    end
  end

  defp get_blocks(height) do
    Model.block(hash: kb_hash) = read_block!({height, -1})
    Model.block(hash: next_kb_hash) = read_block!({height + 1, -1})

    AeMdw.Node.Db.get_blocks(kb_hash, next_kb_hash)
  end
end
