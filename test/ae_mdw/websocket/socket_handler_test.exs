defmodule AeMdw.Websocket.SocketHandlerTest do
  use ExUnit.Case, async: false

  alias Support.WsClient

  import AeMdw.Util.Encoding

  describe "subscribe to KeyBlocks" do
    test "returns the subscriptions list" do
      {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")
      {:ok, client_v2} = WsClient.start_link("ws://localhost:4003/v2/websocket")

      WsClient.subscribe(client, :key_blocks)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive ["KeyBlocks"], 300

      Process.send_after(client_v2, {:subs, self()}, 100)
      assert_receive [], 300

      WsClient.subscribe(client_v2, :key_blocks)
      WsClient.unsubscribe(client, :key_blocks)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive [], 300

      Process.send_after(client_v2, {:subs, self()}, 100)
      assert_receive ["KeyBlocks"], 300

      Process.send_after(client, {:error, self()}, 100)
      assert_receive nil, 300
    end

    test "returns error message when already subscribed" do
      {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")

      on_exit(fn -> WsClient.unsubscribe(client, :key_blocks) end)

      WsClient.subscribe(client, :key_blocks)
      WsClient.subscribe(client, :key_blocks)

      Process.send_after(client, {:error, self()}, 100)
      assert_receive "already subscribed to: KeyBlocks", 300
    end
  end

  describe "subscribe to MicroBlocks" do
    test "returns the subscriptions list" do
      {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")
      {:ok, client_v2} = WsClient.start_link("ws://localhost:4003/v2/websocket")

      WsClient.subscribe(client, :micro_blocks)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive ["MicroBlocks"], 300

      Process.send_after(client_v2, {:subs, self()}, 100)
      assert_receive [], 300

      WsClient.subscribe(client_v2, :micro_blocks)
      WsClient.unsubscribe(client, :micro_blocks)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive [], 300

      Process.send_after(client_v2, {:subs, self()}, 100)
      assert_receive ["MicroBlocks"], 300

      Process.send_after(client, {:error, self()}, 100)
      assert_receive nil, 300
    end

    test "returns error message when already subscribed" do
      {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")

      on_exit(fn -> WsClient.unsubscribe(client, :micro_blocks) end)

      WsClient.subscribe(client, :micro_blocks)
      WsClient.subscribe(client, :micro_blocks)

      Process.send_after(client, {:error, self()}, 100)
      assert_receive "already subscribed to: MicroBlocks", 300
    end
  end

  describe "subscribe to Transactions" do
    test "returns the subscriptions list" do
      {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")
      {:ok, client_v2} = WsClient.start_link("ws://localhost:4003/v2/websocket")

      WsClient.subscribe(client, :transactions)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive ["Transactions"], 300

      Process.send_after(client_v2, {:subs, self()}, 100)
      assert_receive [], 300

      WsClient.subscribe(client_v2, :transactions)
      WsClient.unsubscribe(client, :transactions)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive [], 300

      Process.send_after(client_v2, {:subs, self()}, 100)
      assert_receive ["Transactions"], 300

      Process.send_after(client, {:error, self()}, 100)
      assert_receive nil, 300
    end

    test "returns error message when already subscribed" do
      {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")

      on_exit(fn -> WsClient.unsubscribe(client, :transactions) end)

      WsClient.subscribe(client, :transactions)
      WsClient.subscribe(client, :transactions)

      Process.send_after(client, {:error, self()}, 100)
      assert_receive "already subscribed to: Transactions", 300
    end
  end

  describe "subscribe to Object" do
    test "returns the subscriptions list" do
      {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")
      {:ok, client_v2} = WsClient.start_link("ws://localhost:4003/v2/websocket")

      account_id = encode(:account_pubkey, <<1::256>>)
      contract_id = encode(:contract_pubkey, <<2::256>>)
      oracle_id = encode(:oracle_pubkey, <<3::256>>)
      name_id = encode(:name, <<4::256>>)
      channel_id = encode(:channel, <<5::256>>)

      WsClient.subscribe(client, account_id)
      WsClient.subscribe(client, contract_id)
      WsClient.subscribe(client, oracle_id)
      WsClient.subscribe(client, name_id)
      WsClient.subscribe(client, channel_id)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive [^account_id, ^contract_id, ^oracle_id, ^name_id, ^channel_id], 300

      Process.send_after(client_v2, {:subs, self()}, 100)
      assert_receive [], 300

      WsClient.subscribe(client_v2, name_id)
      WsClient.subscribe(client_v2, channel_id)

      WsClient.unsubscribe(client, account_id)
      WsClient.unsubscribe(client, channel_id)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive [^contract_id, ^oracle_id, ^name_id], 300

      Process.send_after(client_v2, {:subs, self()}, 100)
      assert_receive [^name_id, ^channel_id], 300

      Process.send_after(client, {:error, self()}, 100)
      assert_receive nil, 300
    end

    test "returns error message when already subscribed" do
      {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")

      account_id = encode(:account_pubkey, <<1::256>>)
      WsClient.subscribe(client, account_id)
      Process.send_after(client, {:subs, self()}, 100)
      assert_receive [^account_id], 300

      WsClient.subscribe(client, account_id)
      Process.send_after(client, {:error, self()}, 100)
      error_msg = "already subscribed to target: #{account_id}"
      assert_receive ^error_msg, 300
    end

    test "returns error message when object is invalid" do
      {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")

      account_id = encode(:account_pubkey, <<1::256>>)
      invalid_id = String.replace(account_id, "ak", "pk")

      WsClient.subscribe(client, invalid_id)
      Process.send_after(client, {:error, self()}, 100)
      error_msg = "invalid target: #{invalid_id}"
      assert_receive ^error_msg, 300
    end
  end

  describe "unknown subscription" do
    test "returns the subscriptions list" do
      {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")

      WsClient.subscribe(client, :unknown)
      Process.send_after(client, {:error, self()}, 100)
      error_msg = "invalid payload: Unknown"
      assert_receive ^error_msg, 300
    end
  end
end
