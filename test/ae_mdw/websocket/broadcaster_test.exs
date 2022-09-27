defmodule AeMdw.Websocket.BroadcasterTest do
  use ExUnit.Case, async: false

  alias AeMdwWeb.Websocket.Broadcaster
  alias Support.WsClient

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, spend_tx: 3]
  import Mock

  setup_all do
    clients =
      for _i <- 1..12 do
        {:ok, client} = WsClient.start_link("ws://localhost:4001/websocket")
        client
      end

    [clients: clients]
  end

  describe "broadcast_key_block" do
    test "broadcasts node and mdw keyblock only once", %{clients: clients} do
      with_blockchain %{}, kb0: [], kb1: [], kb2: [] do
        clients
        |> Enum.take(3)
        |> assert_receive_key_blocks(blocks)
      end
    end
  end

  describe "broadcast_micro_block" do
    test "broadcasts node and mdw microblock only once", %{clients: clients} do
      with_blockchain %{alice: 10_000, bob: 5_000, charlie: 2_000},
        mb0: [
          t0: spend_tx(:alice, :bob, 1_000)
        ],
        mb1: [
          t1: spend_tx(:bob, :charlie, 1_000)
        ],
        mb2: [
          t2: spend_tx(:charlie, :alice, 1_000)
        ] do
        clients
        |> Enum.drop(3)
        |> Enum.take(3)
        |> assert_receive_micro_blocks(blocks)
      end
    end
  end

  describe "broadcast_txs" do
    test "broadcasts node and mdw transactions only once", %{clients: clients} do
      with_blockchain %{alice: 10_000, bob: 5_000, charlie: 4_000},
        mb0: [
          t0: spend_tx(:alice, :bob, 2_000)
        ],
        mb1: [
          t1: spend_tx(:bob, :alice, 1_000),
          t2: spend_tx(:bob, :charlie, 3_000)
        ],
        mb2: [
          t3: spend_tx(:charlie, :alice, 4_000)
        ] do
        clients
        |> Enum.drop(6)
        |> Enum.take(3)
        |> assert_receive_transactions(blocks)
      end
    end

    test "broadcasts node and mdw objects only once", %{clients: clients} do
      with_blockchain %{alice: 10_000, bob: 5_000, charlie: 4_000, nakamoto: 1_000_000},
        mb0: [
          t0: spend_tx(:alice, :bob, 2_000)
        ],
        mb1: [
          t1: spend_tx(:bob, :charlie, 3_000),
          t2: spend_tx(:bob, :alice, 1_000),
          t3: spend_tx(:alice, :charlie, 3_000)
        ],
        mb2: [
          t4: spend_tx(:charlie, :nakamoto, 4_000)
        ] do
        {:id, :account, alice_pk} = accounts[:alice]
        alice_id = encode(:account_pubkey, alice_pk)

        clients
        |> Enum.drop(9)
        |> Enum.take(3)
        |> assert_receive_objects(blocks, alice_id)
      end
    end
  end

  defp assert_receive_key_blocks(clients, blocks) do
    Enum.each(clients, &WsClient.subscribe(&1, :key_blocks))
    assert_websocket_receive(clients, :subs, ["KeyBlocks"])

    %{hash: kb_hash0, height: 0, block: block0} = blocks[:kb0]
    %{hash: kb_hash1, height: 1, block: block1} = blocks[:kb1]
    %{hash: kb_hash2, height: 2, block: block2} = blocks[:kb2]

    Broadcaster.broadcast_key_block(block0, :node)

    assert_websocket_receive(clients, :kb, %{
      "payload" => %{"hash" => kb_hash0, "height" => 0},
      "source" => "node",
      "subscription" => "KeyBlocks"
    })

    Broadcaster.broadcast_key_block(block1, :node)

    assert_websocket_receive(clients, :kb, %{
      "payload" => %{"hash" => kb_hash1, "height" => 1},
      "source" => "node",
      "subscription" => "KeyBlocks"
    })

    Broadcaster.broadcast_key_block(block0, :mdw)

    assert_websocket_receive(clients, :kb, %{
      "payload" => %{"hash" => kb_hash0, "height" => 0},
      "source" => "mdw",
      "subscription" => "KeyBlocks"
    })

    Broadcaster.broadcast_key_block(block1, :mdw)

    assert_websocket_receive(clients, :kb, %{
      "payload" => %{"hash" => kb_hash1, "height" => 1},
      "source" => "mdw",
      "subscription" => "KeyBlocks"
    })

    Broadcaster.broadcast_key_block(block2, :node)
    assert_websocket_receive(clients, :kb, %{"payload" => %{"hash" => kb_hash2, "height" => 2}})

    Broadcaster.broadcast_key_block(block0, :node)
    assert_websocket_receive(clients, :kb, %{"payload" => %{"hash" => kb_hash2, "height" => 2}})

    Broadcaster.broadcast_key_block(block1, :mdw)
    assert_websocket_receive(clients, :kb, %{"payload" => %{"hash" => kb_hash2, "height" => 2}})
  end

  defp assert_receive_micro_blocks(clients, blocks) do
    Enum.each(clients, &WsClient.subscribe(&1, :micro_blocks))
    assert_websocket_receive(clients, :subs, ["MicroBlocks"])

    %{hash: mb_hash0, height: 0, block: block0} = blocks[:mb0]
    %{hash: mb_hash1, height: 1, block: block1} = blocks[:mb1]
    %{hash: mb_hash2, height: 2, block: block2} = blocks[:mb2]

    Broadcaster.broadcast_micro_block(block0, :node)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash0, "height" => 0},
      "source" => "node",
      "subscription" => "MicroBlocks"
    })

    Broadcaster.broadcast_micro_block(block1, :node)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash1, "height" => 1},
      "source" => "node",
      "subscription" => "MicroBlocks"
    })

    Broadcaster.broadcast_micro_block(block0, :mdw)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash0, "height" => 0},
      "source" => "mdw",
      "subscription" => "MicroBlocks"
    })

    Broadcaster.broadcast_micro_block(block1, :mdw)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash1, "height" => 1},
      "source" => "mdw",
      "subscription" => "MicroBlocks"
    })

    Broadcaster.broadcast_micro_block(block2, :node)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash2, "height" => 2}
    })

    Broadcaster.broadcast_micro_block(block0, :node)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash2, "height" => 2}
    })

    Broadcaster.broadcast_micro_block(block1, :mdw)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash2, "height" => 2}
    })
  end

  defp assert_receive_transactions(clients, blocks) do
    Enum.each(clients, &WsClient.subscribe(&1, :transactions))
    assert_websocket_receive(clients, :subs, ["Transactions"])

    %{hash: mb_hash0, height: 0, block: block0, txs: [tx0]} = blocks[:mb0]
    %{hash: mb_hash1, height: 1, block: block1, txs: [tx1, tx2]} = blocks[:mb1]
    %{hash: mb_hash2, height: 2, block: block2, txs: [tx3]} = blocks[:mb2]
    tx_hash0 = encode(:tx_hash, :aetx_sign.hash(tx0))
    tx_hash1 = encode(:tx_hash, :aetx_sign.hash(tx1))
    tx_hash2 = encode(:tx_hash, :aetx_sign.hash(tx2))
    tx_hash3 = encode(:tx_hash, :aetx_sign.hash(tx3))

    Broadcaster.broadcast_txs(block0, :node)

    assert_websocket_receive(clients, :txs, [
      %{
        "payload" => %{
          "tx" => %{"type" => "SpendTx", "amount" => 2_000},
          "hash" => tx_hash0,
          "block_height" => 0,
          "block_hash" => mb_hash0
        },
        "source" => "node",
        "subscription" => "Transactions"
      }
    ])

    Enum.each(clients, &WsClient.delete_transactions/1)
    Broadcaster.broadcast_txs(block1, :node)

    assert_websocket_receive(clients, :txs, [
      %{
        "payload" => %{
          "tx" => %{"type" => "SpendTx", "amount" => 1_000},
          "hash" => tx_hash1,
          "block_height" => 1,
          "block_hash" => mb_hash1
        },
        "source" => "node",
        "subscription" => "Transactions"
      },
      %{
        "payload" => %{
          "tx" => %{"type" => "SpendTx", "amount" => 3_000},
          "hash" => tx_hash2,
          "block_height" => 1,
          "block_hash" => mb_hash1
        },
        "source" => "node",
        "subscription" => "Transactions"
      }
    ])

    Enum.each(clients, &WsClient.delete_transactions/1)
    Broadcaster.broadcast_txs(block0, :mdw)

    assert_websocket_receive(clients, :txs, [
      %{
        "payload" => %{
          "tx" => %{"type" => "SpendTx", "amount" => 2_000},
          "hash" => tx_hash0,
          "block_height" => 0,
          "block_hash" => mb_hash0
        },
        "source" => "mdw",
        "subscription" => "Transactions"
      }
    ])

    Enum.each(clients, &WsClient.delete_transactions/1)
    Broadcaster.broadcast_txs(block1, :mdw)

    assert_websocket_receive(clients, :txs, [
      %{
        "payload" => %{
          "tx" => %{"type" => "SpendTx", "amount" => 1_000},
          "hash" => tx_hash1,
          "block_height" => 1,
          "block_hash" => mb_hash1
        },
        "source" => "mdw",
        "subscription" => "Transactions"
      },
      %{
        "payload" => %{
          "tx" => %{"type" => "SpendTx", "amount" => 3_000},
          "hash" => tx_hash2,
          "block_height" => 1,
          "block_hash" => mb_hash1
        },
        "source" => "mdw",
        "subscription" => "Transactions"
      }
    ])

    Enum.each(clients, &WsClient.delete_transactions/1)
    Broadcaster.broadcast_txs(block2, :node)

    assert_websocket_receive(clients, :txs, [
      %{
        "payload" => %{
          "tx" => %{"type" => "SpendTx", "amount" => 4_000},
          "hash" => tx_hash3,
          "block_height" => 2,
          "block_hash" => mb_hash2
        },
        "source" => "node",
        "subscription" => "Transactions"
      }
    ])

    Enum.each(clients, &WsClient.delete_transactions/1)
    Broadcaster.broadcast_txs(block0, :node)
    assert_websocket_receive(clients, :txs, [])

    Enum.each(clients, &WsClient.delete_transactions/1)
    Broadcaster.broadcast_txs(block1, :mdw)
    assert_websocket_receive(clients, :txs, [])
  end

  defp assert_receive_objects(clients, blocks, object_id) do
    Enum.each(clients, &WsClient.subscribe(&1, object_id))
    assert_websocket_receive(clients, :subs, [object_id])

    %{hash: mb_hash0, height: 0, block: block0, txs: [tx0]} = blocks[:mb0]
    %{hash: mb_hash1, height: 1, block: block1, txs: [_tx1, tx2, tx3]} = blocks[:mb1]
    %{hash: _mb_hash2, height: 2, block: block2, txs: [_tx4]} = blocks[:mb2]
    tx_hash0 = encode(:tx_hash, :aetx_sign.hash(tx0))
    tx_hash2 = encode(:tx_hash, :aetx_sign.hash(tx2))
    tx_hash3 = encode(:tx_hash, :aetx_sign.hash(tx3))

    Broadcaster.broadcast_txs(block0, :node)

    assert_websocket_receive(clients, :objs, [
      %{
        "payload" => %{
          "tx" => %{
            "type" => "SpendTx",
            "amount" => 2_000,
            "sender_id" => object_id
          },
          "hash" => tx_hash0,
          "block_height" => 0,
          "block_hash" => mb_hash0
        },
        "source" => "node",
        "subscription" => "Object"
      }
    ])

    Enum.each(clients, &WsClient.delete_objects/1)
    Broadcaster.broadcast_txs(block1, :node)

    assert_websocket_receive(clients, :objs, [
      %{
        "payload" => %{
          "tx" => %{
            "type" => "SpendTx",
            "amount" => 1_000,
            "recipient_id" => object_id
          },
          "hash" => tx_hash2,
          "block_height" => 1,
          "block_hash" => mb_hash1
        },
        "source" => "node",
        "subscription" => "Object"
      },
      %{
        "payload" => %{
          "tx" => %{
            "type" => "SpendTx",
            "amount" => 3_000,
            "sender_id" => object_id
          },
          "hash" => tx_hash3,
          "block_height" => 1,
          "block_hash" => mb_hash1
        },
        "source" => "node",
        "subscription" => "Object"
      }
    ])

    Enum.each(clients, &WsClient.delete_objects/1)
    Broadcaster.broadcast_txs(block2, :node)
    assert_websocket_receive(clients, :objs, [])

    Enum.each(clients, &WsClient.delete_objects/1)
    Broadcaster.broadcast_txs(block0, :mdw)

    assert_websocket_receive(clients, :objs, [
      %{
        "payload" => %{
          "tx" => %{
            "type" => "SpendTx",
            "amount" => 2_000,
            "sender_id" => object_id
          },
          "hash" => tx_hash0,
          "block_height" => 0,
          "block_hash" => mb_hash0
        },
        "source" => "mdw",
        "subscription" => "Object"
      }
    ])

    Enum.each(clients, &WsClient.delete_objects/1)
    Broadcaster.broadcast_txs(block1, :mdw)

    assert_websocket_receive(clients, :objs, [
      %{
        "payload" => %{
          "tx" => %{
            "type" => "SpendTx",
            "amount" => 1_000,
            "recipient_id" => object_id
          },
          "hash" => tx_hash2,
          "block_height" => 1,
          "block_hash" => mb_hash1
        },
        "source" => "mdw",
        "subscription" => "Object"
      },
      %{
        "payload" => %{
          "tx" => %{
            "type" => "SpendTx",
            "amount" => 3_000,
            "sender_id" => object_id
          },
          "hash" => tx_hash3,
          "block_height" => 1,
          "block_hash" => mb_hash1
        },
        "source" => "mdw",
        "subscription" => "Object"
      }
    ])

    Enum.each(clients, &WsClient.delete_objects/1)
    Broadcaster.broadcast_txs(block0, :node)
    assert_websocket_receive(clients, :objs, [])

    Enum.each(clients, &WsClient.delete_objects/1)
    Broadcaster.broadcast_txs(block1, :mdw)
    assert_websocket_receive(clients, :objs, [])
  end

  defp assert_websocket_receive(clients, key, [
         %{"payload" => %{"tx" => tx1} = payload1} = msg1,
         %{"payload" => %{"tx" => tx2} = payload2} = msg2
       ]) do
    msg1_without_payload = Map.delete(msg1, "payload")
    msg2_without_payload = Map.delete(msg2, "payload")
    payload1_without_tx = Map.delete(payload1, "tx")
    payload2_without_tx = Map.delete(payload2, "tx")

    clients
    |> Enum.map(fn client ->
      Task.async(fn ->
        Process.send_after(client, {key, self()}, 100)

        assert_receive [
                         %{"payload" => message_payload1} = message1,
                         %{"payload" => message_payload2} = message2
                       ],
                       300

        assert MapSet.subset?(MapSet.new(tx1), MapSet.new(message_payload1["tx"]))
        assert MapSet.subset?(MapSet.new(payload1_without_tx), MapSet.new(message_payload1))
        assert MapSet.subset?(MapSet.new(msg1_without_payload), MapSet.new(message1))

        assert MapSet.subset?(MapSet.new(tx2), MapSet.new(message_payload2["tx"]))
        assert MapSet.subset?(MapSet.new(payload2_without_tx), MapSet.new(message_payload2))
        assert MapSet.subset?(MapSet.new(msg2_without_payload), MapSet.new(message2))
      end)
    end)
    |> Task.await_many()
  end

  defp assert_websocket_receive(clients, key, %{"payload" => payload} = msg) do
    msg_without_payload = Map.delete(msg, "payload")

    clients
    |> Enum.map(fn client ->
      Task.async(fn ->
        Process.send_after(client, {key, self()}, 100)
        assert_receive message, 300
        assert MapSet.subset?(MapSet.new(payload), MapSet.new(message["payload"]))
        assert MapSet.subset?(MapSet.new(msg_without_payload), MapSet.new(message))
      end)
    end)
    |> Task.await_many()
  end

  defp assert_websocket_receive(clients, key, [%{"payload" => %{"tx" => tx} = payload} = msg]) do
    msg_without_payload = Map.delete(msg, "payload")
    payload_without_tx = Map.delete(payload, "tx")

    clients
    |> Enum.map(fn client ->
      Task.async(fn ->
        Process.send_after(client, {key, self()}, 100)
        assert_receive [%{"payload" => message_payload} = message], 300
        assert MapSet.subset?(MapSet.new(tx), MapSet.new(message_payload["tx"]))
        assert MapSet.subset?(MapSet.new(payload_without_tx), MapSet.new(message_payload))
        assert MapSet.subset?(MapSet.new(msg_without_payload), MapSet.new(message))
      end)
    end)
    |> Task.await_many()
  end

  defp assert_websocket_receive(clients, key, list) when is_list(list) do
    clients
    |> Enum.map(fn client ->
      Task.async(fn ->
        Process.send_after(client, {key, self()}, 100)
        assert_receive ^list, 300
      end)
    end)
    |> Task.await_many()
  end

  defp encode(type, pk), do: :aeser_api_encoder.encode(type, pk)
end
