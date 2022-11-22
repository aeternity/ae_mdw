defmodule AeMdw.Websocket.SubscriptionsTest do
  use ExUnit.Case, async: false

  alias AeMdwWeb.Websocket.Subscriptions
  alias AeMdw.Validate

  import AeMdw.Util.Encoding
  import Support.WsUtil

  describe "subscribe/2" do
    test "returns all subscribed channels on success" do
      pid1 = new_pid()
      pid2 = new_pid()
      pid3 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2, pid3]) end)

      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid1, "KeyBlocks")
      assert {:ok, ["MicroBlocks"]} = Subscriptions.subscribe(pid2, "MicroBlocks")
      assert {:ok, ["KeyBlocks", "Transactions"]} = Subscriptions.subscribe(pid1, "Transactions")

      channel = encode(:account_pubkey, <<11::256>>)
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid3, channel)
      assert {:ok, [^channel, "Transactions"]} = Subscriptions.subscribe(pid3, "Transactions")
    end

    test "returns invalid channel when unknown and not a valid id" do
      channel = "ak_2iK7D3t5xyN8GHxQktvBnfoC3tpq1eVMzTpABQY72FXRfg3HMZ"
      assert {:error, _reason} = Validate.id(channel)
      assert {:error, :invalid_channel} = Subscriptions.subscribe(new_pid(), channel)
    end

    test "returns error on duplicate subscriptions" do
      pid = new_pid()
      channel = encode(:account_pubkey, <<12::256>>)
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid, channel)
      assert {:error, :already_subscribed} = Subscriptions.subscribe(pid, channel)
    end
  end

  describe "unsubscribe/2" do
    test "returns remaining subscribed channels" do
      pid1 = new_pid()
      pid2 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2]) end)

      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid1, "KeyBlocks")
      assert {:ok, ["KeyBlocks", "Transactions"]} = Subscriptions.subscribe(pid1, "Transactions")
      assert {:ok, ["MicroBlocks"]} = Subscriptions.subscribe(pid2, "MicroBlocks")

      assert {:ok, ["Transactions"]} = Subscriptions.unsubscribe(pid1, "KeyBlocks")
      assert {:ok, []} = Subscriptions.unsubscribe(pid2, "MicroBlocks")
    end

    test "returns error when channel is unknown and not a valid id" do
      pk_channel = "ak_2iK7D3t5xyN8GHxQktvBnfoC3tpq1eVMzTpABQY72FXRfg3HMZ"
      assert {:error, _reason} = Validate.id(pk_channel)
      assert {:error, :invalid_channel} = Subscriptions.unsubscribe(new_pid(), pk_channel)
    end

    test "returns error on uknonw unsubscription" do
      assert {:error, :not_subscribed} = Subscriptions.unsubscribe(new_pid(), "KeyBlocks")
    end
  end

  describe "subscribers/1" do
    test "returns all subscribers of a channel" do
      pid1 = new_pid()
      pid2 = new_pid()
      pid3 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2, pid3]) end)

      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid1, "KeyBlocks")
      channel = encode(:account_pubkey, <<13::256>>)
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid2, channel)
      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid3, "KeyBlocks")

      list = Subscriptions.subscribers("KeyBlocks")
      assert pid1 in list and pid3 in list
      assert [^pid2] = Subscriptions.subscribers(Validate.id!(channel))
    end

    test "returns empty list when there are none for a channel" do
      channel = encode(:account_pubkey, <<14::256>>)
      assert [] = Subscriptions.subscribers(channel)
    end
  end

  describe "subscribed_channels/1" do
    test "returns channels of a subscriber" do
      pid1 = new_pid()
      pid2 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2]) end)

      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid1, "KeyBlocks")
      channel = encode(:account_pubkey, <<15::256>>)
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid2, channel)

      assert ["KeyBlocks"] = Subscriptions.subscribed_channels(pid1)
      assert [^channel] = Subscriptions.subscribed_channels(pid2)
    end

    test "returns no channels after subscriber goes DOWN" do
      pid1 = new_pid()
      pid2 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2]) end)

      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid1, "KeyBlocks")
      assert {:ok, ["MicroBlocks"]} = Subscriptions.subscribe(pid2, "MicroBlocks")

      assert ["KeyBlocks"] = Subscriptions.subscribed_channels(pid1)
      Process.exit(pid1, :kill)
      assert [] = Subscriptions.subscribed_channels("KeyBlocks")
      assert ["MicroBlocks"] = Subscriptions.subscribed_channels(pid2)
    end
  end

  defp new_pid(), do: spawn(fn -> Process.sleep(1_000) end)
end
