defmodule AeMdw.Websocket.SocketHandlerTest do
  use ExUnit.Case, async: false

  alias Support.WsClient

  import AeMdw.Util.Encoding

  setup_all do
    clients =
      for _i <- 1..9 do
        {:ok, client} = WsClient.start_link("ws://localhost:4003/websocket")
        client
      end

    [clients: clients]
  end

  describe "subscribe to KeyBlocks" do
    test "returns the subscriptions list", %{clients: clients} do
      client = Enum.at(clients, 0)

      WsClient.subscribe(client, :key_blocks)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive ["KeyBlocks"], 300
    end

    test "returns error message when already subscribed", %{clients: clients} do
      client = Enum.at(clients, 1)

      WsClient.subscribe(client, :key_blocks)
      WsClient.subscribe(client, :key_blocks)

      Process.send_after(client, {:error, self()}, 100)
      assert_receive "already subscribed to: KeyBlocks", 300
    end
  end

  describe "subscribe to MicroBlocks" do
    test "returns the subscriptions list", %{clients: clients} do
      client = Enum.at(clients, 2)

      WsClient.subscribe(client, :micro_blocks)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive ["MicroBlocks"], 300
    end

    test "returns error message when already subscribed", %{clients: clients} do
      client = Enum.at(clients, 3)

      WsClient.subscribe(client, :micro_blocks)
      WsClient.subscribe(client, :micro_blocks)

      Process.send_after(client, {:error, self()}, 100)
      assert_receive "already subscribed to: MicroBlocks", 300
    end
  end

  describe "subscribe to Transactions" do
    test "returns the subscriptions list", %{clients: clients} do
      client = Enum.at(clients, 4)

      WsClient.subscribe(client, :transactions)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive ["Transactions"], 300
    end

    test "returns error message when already subscribed", %{clients: clients} do
      client = Enum.at(clients, 5)

      WsClient.subscribe(client, :transactions)
      WsClient.subscribe(client, :transactions)

      Process.send_after(client, {:error, self()}, 100)
      assert_receive "already subscribed to: Transactions", 300
    end
  end

  describe "subscribe to Object" do
    test "returns the subscriptions list", %{clients: clients} do
      client = Enum.at(clients, 6)

      account_id = encode(:account_pubkey, <<1::256>>)
      contract_id = encode(:contract_pubkey, <<2::256>>)
      oracle_id = encode(:oracle_pubkey, <<1::256>>)
      name_id = encode(:name, <<4::256>>)
      channel_id = encode(:channel, <<5::256>>)

      WsClient.subscribe(client, account_id)
      WsClient.subscribe(client, contract_id)
      WsClient.subscribe(client, oracle_id)
      WsClient.subscribe(client, name_id)
      WsClient.subscribe(client, channel_id)

      Process.send_after(client, {:subs, self()}, 100)
      assert_receive [^channel_id, ^name_id, ^oracle_id, ^contract_id, ^account_id], 300

      Process.send_after(client, {:error, self()}, 100)
      assert_receive nil, 300
    end

    test "returns error message when already subscribed", %{clients: clients} do
      client = Enum.at(clients, 7)

      account_id = encode(:account_pubkey, <<1::256>>)
      WsClient.subscribe(client, account_id)
      Process.send_after(client, {:subs, self()}, 100)
      assert_receive [^account_id], 300

      WsClient.subscribe(client, account_id)
      Process.send_after(client, {:error, self()}, 100)
      error_msg = "already subscribed to target: #{account_id}"
      assert_receive ^error_msg, 300
    end

    test "returns error message when object is invalid", %{clients: clients} do
      client = Enum.at(clients, 8)

      account_id = encode(:account_pubkey, <<1::256>>)
      invalid_id = String.replace(account_id, "ak", "pk")

      WsClient.subscribe(client, invalid_id)
      Process.send_after(client, {:error, self()}, 100)
      error_msg = "invalid target: #{invalid_id}"
      assert_receive ^error_msg, 300
    end
  end
end
