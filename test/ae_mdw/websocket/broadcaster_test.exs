defmodule AeMdw.Websocket.BroadcasterTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Validate
  alias AeMdwWeb.Websocket.Broadcaster
  alias Support.WsClient

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, spend_tx: 3, name_tx: 3]
  import Support.WsUtil, only: [unsubscribe_all: 1]
  import Mock

  require Model

  setup_all do
    clients =
      for _i <- 1..12 do
        {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")
        client
      end

    [clients: clients]
  end

  describe "broadcast_key_block" do
    test "broadcasts node and mdw keyblock only once", %{clients: clients} do
      with_blockchain %{}, kb0: [], kb1: [], kb2: [] do
        clients = Enum.take(clients, 3)

        Enum.each(clients, &WsClient.subscribe(&1, :key_blocks, :node))
        assert_websocket_receive(clients, :subs, ["KeyBlocks"])
        assert_receive_key_blocks(clients, blocks, :v1, :node)
        unsubscribe_all(clients)

        Enum.each(clients, &WsClient.unsubscribe(&1, :key_blocks, :node))
        Enum.each(clients, &WsClient.delete_subscriptions/1)

        Enum.each(clients, &WsClient.subscribe(&1, :key_blocks, :mdw))
        assert_websocket_receive(clients, :subs, ["KeyBlocks"])
        assert_receive_key_blocks(clients, blocks, :v1, :mdw)
        unsubscribe_all(clients)
      end
    end

    test "broadcasts node and mdw keyblock for v2" do
      with_blockchain %{}, kb0: [], kb1: [], kb2: [] do
        %{hash: kb_hash0, height: 0} = blocks[:kb0]
        %{hash: kb_hash1, height: 1} = blocks[:kb1]
        %{hash: kb_hash2, height: 2} = blocks[:kb2]

        state =
          State.mem_state()
          |> State.put(
            Model.Block,
            Model.block(index: {0, -1}, hash: Validate.id!(kb_hash0), tx_index: 0)
          )
          |> State.put(
            Model.Block,
            Model.block(index: {1, -1}, hash: Validate.id!(kb_hash1), tx_index: 0)
          )
          |> State.put(
            Model.Block,
            Model.block(index: {2, -1}, hash: Validate.id!(kb_hash2), tx_index: 0)
          )

        :persistent_term.put(:global_state, state)

        clients =
          for _i <- 1..3 do
            {:ok, client} = WsClient.start_link("ws://localhost:4003/v2/websocket")
            client
          end

        Enum.each(clients, &WsClient.subscribe(&1, :key_blocks, :mdw))
        assert_websocket_receive(clients, :subs, ["KeyBlocks"])
        assert_receive_key_blocks(clients, blocks, :v2, :mdw)
        unsubscribe_all(clients)
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
        clients =
          clients
          |> Enum.drop(3)
          |> Enum.take(3)

        Enum.each(clients, &WsClient.subscribe(&1, :micro_blocks, :node))
        assert_websocket_receive(clients, :subs, ["MicroBlocks"])
        assert_receive_micro_blocks(clients, blocks, :node)
        unsubscribe_all(clients)

        Enum.each(clients, &WsClient.unsubscribe(&1, :micro_blocks, :node))
        Enum.each(clients, &WsClient.delete_subscriptions/1)

        Enum.each(clients, &WsClient.subscribe(&1, :micro_blocks, :mdw))
        assert_websocket_receive(clients, :subs, ["MicroBlocks"])
        assert_receive_micro_blocks(clients, blocks, :mdw)
        unsubscribe_all(clients)
      end
    end

    test "broadcasts node and mdw microblock for v2" do
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
        %{hash: mb_hash0, height: 0} = blocks[:mb0]
        %{hash: mb_hash1, height: 1} = blocks[:mb1]
        %{hash: mb_hash2, height: 2} = blocks[:mb2]

        state =
          State.mem_state()
          |> State.put(
            Model.Block,
            Model.block(index: {0, 0}, hash: Validate.id!(mb_hash0), tx_index: 0)
          )
          |> State.put(
            Model.Block,
            Model.block(index: {1, 0}, hash: Validate.id!(mb_hash1), tx_index: 1)
          )
          |> State.put(
            Model.Block,
            Model.block(index: {2, 0}, hash: Validate.id!(mb_hash2), tx_index: 2)
          )

        :persistent_term.put(:global_state, state)

        clients =
          for _i <- 1..3 do
            {:ok, client} = WsClient.start_link("ws://localhost:4003/v2/websocket")
            client
          end

        Enum.each(clients, &WsClient.subscribe(&1, :micro_blocks, :mdw))
        assert_websocket_receive(clients, :subs, ["MicroBlocks"])
        assert_receive_micro_blocks(clients, blocks, :mdw)
        unsubscribe_all(clients)
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
        clients =
          clients
          |> Enum.drop(6)
          |> Enum.take(3)

        assert_receive_transactions(clients, blocks)
        unsubscribe_all(clients)
      end
    end

    test "broadcasts node and mdw objects only once", %{clients: clients} do
      plain_name = "nakamotodesu.chain"
      {:ok, name_hash} = :aens.get_name_hash(plain_name)

      with_blockchain %{alice: 10_000, bob: 5_000, charlie: 9_000, nakamoto: 1_000_000},
        mb0: [
          tx0: spend_tx(:alice, :bob, 100)
        ],
        mb1: [
          tx1: spend_tx(:bob, :alice, 1_000),
          tx2: spend_tx(:charlie, :bob, 2_000),
          tx3: spend_tx(:alice, :charlie, 3_000)
        ],
        mb2: [
          tx4: name_tx(:name_claim_tx, :nakamoto, plain_name),
          tx5: name_tx(:name_update_tx, :nakamoto, plain_name),
          tx6: spend_tx(:nakamoto, :charlie, 6_000)
        ],
        mb3: [
          tx7: spend_tx(:bob, :nakamoto, 7_000)
        ],
        mb4: [
          tx8: spend_tx(:charlie, {:id, :name, name_hash}, 8_000)
        ] do
        {:id, :account, alice_pk} = accounts[:alice]
        alice_id = encode(:account_pubkey, alice_pk)
        name_id = encode(:name, name_hash)

        clients = clients |> Enum.drop(9) |> Enum.take(3)

        Enum.each(clients, fn client ->
          WsClient.subscribe(client, alice_id, :node)
          WsClient.subscribe(client, name_id, :node)
        end)

        assert_websocket_receive(clients, :subs, [alice_id, name_id])

        Enum.each(clients, fn client ->
          WsClient.subscribe(client, alice_id, :mdw)
          WsClient.subscribe(client, name_id, :mdw)
        end)

        %{hash: mb_hash, height: 0, block: block0, txs: [tx0]} = blocks[:mb0]
        tx_hash0 = encode(:tx_hash, :aetx_sign.hash(tx0))

        expected_msg = %{
          "payload" => %{
            "tx" => %{
              "type" => "SpendTx",
              "amount" => 100,
              "sender_id" => alice_id
            },
            "hash" => tx_hash0,
            "block_height" => 0,
            "block_hash" => mb_hash
          },
          "subscription" => "Object"
        }

        Broadcaster.broadcast_txs(block0, :node)

        assert_websocket_receive(clients, :objs, [
          Map.put(expected_msg, "source", "node")
        ])

        Broadcaster.broadcast_txs(block0, :mdw)

        assert_websocket_receive(clients, :objs, [
          Map.put(expected_msg, "source", "mdw")
        ])

        %{hash: mb_hash, height: 1, block: block1, txs: [tx1, _tx2, tx3]} = blocks[:mb1]
        tx_hash1 = encode(:tx_hash, :aetx_sign.hash(tx1))
        tx_hash3 = encode(:tx_hash, :aetx_sign.hash(tx3))

        expected_msg1 = %{
          "payload" => %{
            "tx" => %{
              "type" => "SpendTx",
              "amount" => 1_000,
              "recipient_id" => alice_id
            },
            "hash" => tx_hash1,
            "block_height" => 1,
            "block_hash" => mb_hash
          },
          "source" => "node",
          "subscription" => "Object"
        }

        expected_msg2 = %{
          "payload" => %{
            "tx" => %{
              "type" => "SpendTx",
              "amount" => 3_000,
              "sender_id" => alice_id
            },
            "hash" => tx_hash3,
            "block_height" => 1,
            "block_hash" => mb_hash
          },
          "source" => "node",
          "subscription" => "Object"
        }

        Broadcaster.broadcast_txs(block1, :node)

        assert_websocket_receive(clients, :objs, [
          Map.put(expected_msg1, "source", "node"),
          Map.put(expected_msg2, "source", "node")
        ])

        Broadcaster.broadcast_txs(block1, :mdw)

        assert_websocket_receive(clients, :objs, [
          Map.put(expected_msg1, "source", "mdw"),
          Map.put(expected_msg2, "source", "mdw")
        ])

        %{hash: mb_hash, height: 2, block: block2, txs: [_tx4, tx5, _tx6]} = blocks[:mb2]
        tx_hash5 = encode(:tx_hash, :aetx_sign.hash(tx5))

        expected_msg = %{
          "payload" => %{
            "tx" => %{
              "type" => "NameUpdateTx",
              "name_id" => name_id
            },
            "hash" => tx_hash5,
            "block_height" => 2,
            "block_hash" => mb_hash
          },
          "subscription" => "Object"
        }

        Broadcaster.broadcast_txs(block2, :node)

        assert_websocket_receive(clients, :objs, [
          Map.put(expected_msg, "source", "node")
        ])

        Broadcaster.broadcast_txs(block2, :mdw)

        assert_websocket_receive(clients, :objs, [
          Map.put(expected_msg, "source", "mdw")
        ])

        %{hash: _mb_hash3, height: 3, block: block3, txs: [_tx7]} = blocks[:mb3]
        Broadcaster.broadcast_txs(block3, :node)
        assert_websocket_receive(clients, :objs, [])

        %{hash: mb_hash, height: 4, block: block4, txs: [tx8]} = blocks[:mb4]
        tx_hash8 = encode(:tx_hash, :aetx_sign.hash(tx8))

        expected_msg = %{
          "payload" => %{
            "tx" => %{
              "type" => "SpendTx",
              "amount" => 8_000,
              "recipient_id" => name_id
            },
            "hash" => tx_hash8,
            "block_height" => 4,
            "block_hash" => mb_hash
          },
          "subscription" => "Object"
        }

        Broadcaster.broadcast_txs(block4, :node)

        assert_websocket_receive(clients, :objs, [
          Map.put(expected_msg, "source", "node")
        ])

        Broadcaster.broadcast_txs(block4, :mdw)

        assert_websocket_receive(clients, :objs, [
          Map.put(expected_msg, "source", "mdw")
        ])

        Broadcaster.broadcast_txs(block0, :node)
        assert_websocket_receive(clients, :objs, [])

        Broadcaster.broadcast_txs(block1, :mdw)
        assert_websocket_receive(clients, :objs, [])

        Broadcaster.broadcast_txs(block2, :node)
        assert_websocket_receive(clients, :objs, [])

        Broadcaster.broadcast_txs(block3, :mdw)
        assert_websocket_receive(clients, :objs, [])

        Broadcaster.broadcast_txs(block4, :mdw)
        assert_websocket_receive(clients, :objs, [])
      end
    end
  end

  defp assert_receive_key_blocks(clients, blocks, version, source) do
    %{hash: kb_hash0, height: 0, block: block0} = blocks[:kb0]
    %{hash: kb_hash1, height: 1, block: block1} = blocks[:kb1]
    %{hash: kb_hash2, height: 2, block: block2} = blocks[:kb2]

    Broadcaster.broadcast_key_block(block0, version, source)

    assert_websocket_receive(clients, :kb, %{
      "payload" => %{"hash" => kb_hash0, "height" => 0},
      "source" => to_string(source),
      "subscription" => "KeyBlocks"
    })

    Broadcaster.broadcast_key_block(block1, version, source)

    assert_websocket_receive(clients, :kb, %{
      "payload" => %{"hash" => kb_hash1, "height" => 1},
      "source" => to_string(source),
      "subscription" => "KeyBlocks"
    })

    Broadcaster.broadcast_key_block(block2, version, source)
    assert_websocket_receive(clients, :kb, %{"payload" => %{"hash" => kb_hash2, "height" => 2}})

    Broadcaster.broadcast_key_block(block0, version, source)
    assert_websocket_receive(clients, :kb, %{"payload" => %{"hash" => kb_hash2, "height" => 2}})

    Broadcaster.broadcast_key_block(block1, version, source)
    assert_websocket_receive(clients, :kb, %{"payload" => %{"hash" => kb_hash2, "height" => 2}})
  end

  defp assert_receive_micro_blocks(clients, blocks, source) do
    %{hash: mb_hash0, height: 0, block: block0} = blocks[:mb0]
    %{hash: mb_hash1, height: 1, block: block1} = blocks[:mb1]
    %{hash: mb_hash2, height: 2, block: block2} = blocks[:mb2]

    Broadcaster.broadcast_micro_block(block0, source)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash0, "height" => 0},
      "source" => to_string(source),
      "subscription" => "MicroBlocks"
    })

    Broadcaster.broadcast_micro_block(block1, source)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash1, "height" => 1},
      "source" => to_string(source),
      "subscription" => "MicroBlocks"
    })

    Broadcaster.broadcast_micro_block(block2, source)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash2, "height" => 2},
      "source" => to_string(source),
      "subscription" => "MicroBlocks"
    })

    Broadcaster.broadcast_micro_block(block0, source)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash2, "height" => 2}
    })

    Broadcaster.broadcast_micro_block(block1, source)

    assert_websocket_receive(clients, :mb, %{
      "payload" => %{"hash" => mb_hash2, "height" => 2}
    })
  end

  defp assert_receive_transactions(clients, blocks) do
    Enum.each(clients, &WsClient.subscribe(&1, :transactions, :node))
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

    Enum.each(clients, &WsClient.subscribe(&1, :transactions, :mdw))
    assert_websocket_receive(clients, :subs, ["Transactions", "Transactions"])

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

    if key == :objs, do: Enum.each(clients, &WsClient.delete_objects/1)
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

  defp assert_websocket_receive(clients, key, [%{"payload" => %{"tx" => tx} = payload} = msg])
       when key in [:txs, :objs] do
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

    if key == :objs, do: Enum.each(clients, &WsClient.delete_objects/1)
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
