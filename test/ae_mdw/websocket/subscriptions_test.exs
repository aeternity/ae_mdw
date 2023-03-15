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

      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid1, :node, :v1, "KeyBlocks")
      assert {:ok, ["MicroBlocks"]} = Subscriptions.subscribe(pid2, :node, :v1, "MicroBlocks")

      assert {:ok, ["KeyBlocks", "Transactions"]} =
               Subscriptions.subscribe(pid1, :node, :v1, "Transactions")

      channel = encode(:account_pubkey, :crypto.strong_rand_bytes(32))
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid3, :node, :v1, channel)

      channel = encode(:oracle_pubkey, :crypto.strong_rand_bytes(32))
      assert {:ok, subs} = Subscriptions.subscribe(pid3, :node, :v1, channel)
      assert channel in subs

      channel = encode(:contract_pubkey, :crypto.strong_rand_bytes(32))
      assert {:ok, subs} = Subscriptions.subscribe(pid3, :node, :v1, channel)
      assert channel in subs

      channel = encode(:channel, :crypto.strong_rand_bytes(32))
      assert {:ok, subs} = Subscriptions.subscribe(pid3, :node, :v1, channel)
      assert channel in subs

      channel = encode(:name, :crypto.strong_rand_bytes(32))
      assert {:ok, subs} = Subscriptions.subscribe(pid3, :node, :v1, channel)
      assert channel in subs

      assert {:ok, subs} = Subscriptions.subscribe(pid3, :node, :v1, "Transactions")
      assert channel in subs
    end

    test "returns invalid channel when unknown and not a valid id" do
      channel = "ak_2iK7D3t5xyN8GHxQktvBnfoC3tpq1eVMzTpABQY72FXRfg3HMZ"
      assert {:error, _reason} = Validate.id(channel)
      assert {:error, :invalid_channel} = Subscriptions.subscribe(new_pid(), :node, :v1, channel)
    end

    test "returns error on duplicate subscriptions" do
      pid = new_pid()
      on_exit(fn -> unsubscribe_all([pid]) end)
      channel = encode(:account_pubkey, <<12::256>>)
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid, :node, :v1, channel)
      assert {:error, :already_subscribed} = Subscriptions.subscribe(pid, :node, :v1, channel)
    end

    test "does not allow duplicate subscription of account and oracle with same pubkey" do
      pid = new_pid()
      on_exit(fn -> unsubscribe_all([pid]) end)
      channel = encode(:account_pubkey, <<13::256>>)
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid, :mdw, :v2, channel)

      channel = encode(:oracle_pubkey, <<13::256>>)
      assert {:error, :already_subscribed} = Subscriptions.subscribe(pid, :mdw, :v2, channel)
    end

    test "returns error on subscriptions limit is reached" do
      max_subs =
        Application.get_env(:ae_mdw, AeMdwWeb.Websocket.Subscriptions)[:max_subs_per_conn]

      channel = encode(:account_pubkey, <<1::256>>)
      assert {:ok, _channel_list} = Subscriptions.subscribe(self(), :mdw, :v2, channel)
      Process.sleep(500)

      Enum.each(2..max_subs, fn i ->
        channel = encode(:account_pubkey, <<i::256>>)
        assert {:ok, _channel_list} = Subscriptions.subscribe(self(), :mdw, :v2, channel)
      end)

      channel = encode(:account_pubkey, <<max_subs + 1::256>>)
      assert {:error, :limit_reached} = Subscriptions.subscribe(self(), :mdw, :v2, channel)

      assert {:error, :limit_reached} = Subscriptions.subscribe(self(), :mdw, :v2, "Transactions")
      assert {:error, :limit_reached} = Subscriptions.subscribe(self(), :mdw, :v2, "KeyBlocks")
      assert {:error, :limit_reached} = Subscriptions.subscribe(self(), :mdw, :v2, "MicroBlocks")
    end
  end

  describe "unsubscribe/2" do
    test "returns remaining subscribed channels" do
      pid1 = new_pid()
      pid2 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2]) end)

      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid1, :node, :v1, "KeyBlocks")

      assert {:ok, ["KeyBlocks", "Transactions"]} =
               Subscriptions.subscribe(pid1, :node, :v1, "Transactions")

      assert {:ok, ["MicroBlocks"]} = Subscriptions.subscribe(pid2, :node, :v1, "MicroBlocks")

      assert {:ok, ["Transactions"]} = Subscriptions.unsubscribe(pid1, :node, :v1, "KeyBlocks")
      assert {:ok, []} = Subscriptions.unsubscribe(pid2, :node, :v1, "MicroBlocks")
    end

    test "returns error when channel is unknown and not a valid id" do
      pk_channel = "ak_2iK7D3t5xyN8GHxQktvBnfoC3tpq1eVMzTpABQY72FXRfg3HMZ"
      assert {:error, _reason} = Validate.id(pk_channel)

      assert {:error, :invalid_channel} =
               Subscriptions.unsubscribe(new_pid(), :node, :v1, pk_channel)
    end

    test "returns error on uknonw unsubscription" do
      assert {:error, :not_subscribed} =
               Subscriptions.unsubscribe(new_pid(), :node, :v1, "KeyBlocks")
    end

    test "allowed for account and oracle with same pubkey" do
      pid = new_pid()
      channel = encode(:account_pubkey, <<14::256>>)
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid, :mdw, :v2, channel)

      channel = encode(:oracle_pubkey, <<14::256>>)
      assert {:ok, []} = Subscriptions.unsubscribe(pid, :mdw, :v2, channel)
      assert {:error, :not_subscribed} = Subscriptions.unsubscribe(pid, :mdw, :v2, channel)
    end
  end

  describe "has_subscribers?/3" do
    test "checks if there is any subscriber for a known versioned channel" do
      pid1 = new_pid()
      pid2 = new_pid()
      pid3 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2, pid3]) end)

      unsubscribe_all(:v1)
      unsubscribe_all(:v2)

      channel = encode(:oracle_pubkey, :crypto.strong_rand_bytes(32))
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid1, :mdw, :v2, channel)

      assert {:ok, [^channel, "KeyBlocks"]} =
               Subscriptions.subscribe(pid1, :node, :v1, "KeyBlocks")

      assert {:ok, ["MicroBlocks"]} = Subscriptions.subscribe(pid2, :mdw, :v2, "MicroBlocks")
      assert {:ok, ["Transactions"]} = Subscriptions.subscribe(pid3, :mdw, :v2, "Transactions")

      assert Subscriptions.has_subscribers?(:node, :v1, "KeyBlocks")
      assert Subscriptions.has_subscribers?(:mdw, :v2, "MicroBlocks")
      assert Subscriptions.has_subscribers?(:mdw, :v2, "Transactions")

      refute Subscriptions.has_subscribers?(:mdw, :v2, "KeyBlocks")
      refute Subscriptions.has_subscribers?(:node, :v1, "MicroBlocks")
      refute Subscriptions.has_subscribers?(:node, :v1, "Transactions")
    end
  end

  describe "has_object_subscribers?/2" do
    test "returns true if there is any object channel subscribed for a version" do
      pid1 = new_pid()
      pid2 = new_pid()
      pid3 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2, pid3]) end)

      unsubscribe_all(:v1)
      unsubscribe_all(:v2)

      channel = encode(:oracle_pubkey, :crypto.strong_rand_bytes(32))
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid1, :node, :v1, channel)
      channel = encode(:contract_pubkey, :crypto.strong_rand_bytes(32))
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid2, :mdw, :v2, channel)
      assert {:ok, _list} = Subscriptions.subscribe(pid3, :mdw, :v2, "Transactions")

      assert Subscriptions.has_object_subscribers?(:node, :v1)
      assert Subscriptions.has_object_subscribers?(:mdw, :v2)
    end

    test "returns false if there are no object channel subscribed for a version" do
      pid1 = new_pid()
      pid2 = new_pid()
      pid3 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2, pid3]) end)

      unsubscribe_all(:v1)
      unsubscribe_all(:v2)

      channel1 = encode(:account_pubkey, :crypto.strong_rand_bytes(32))

      assert {:ok, _subs} = Subscriptions.subscribe(pid1, :node, :v1, channel1)
      assert {:ok, _subs} = Subscriptions.subscribe(pid2, :mdw, :v2, "KeyBlocks")
      assert {:ok, _subs} = Subscriptions.subscribe(pid2, :mdw, :v2, "MicroBlocks")
      assert {:ok, _subs} = Subscriptions.subscribe(pid3, :mdw, :v2, "MicroBlocks")
      assert {:ok, _subs} = Subscriptions.subscribe(pid3, :mdw, :v2, "Transactions")

      assert Subscriptions.has_object_subscribers?(:node, :v1)
      refute Subscriptions.has_object_subscribers?(:mdw, :v2)
    end
  end

  describe "subscribers/1" do
    test "returns all subscribers of a channel" do
      pid1 = new_pid()
      pid2 = new_pid()
      pid3 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2, pid3]) end)

      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid1, :node, :v1, "KeyBlocks")
      channel = encode(:account_pubkey, <<13::256>>)
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid2, :node, :v1, channel)
      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid3, :node, :v1, "KeyBlocks")

      list = Subscriptions.subscribers(:node, :v1, "KeyBlocks")
      assert pid1 in list and pid3 in list
      assert [^pid2] = Subscriptions.subscribers(:node, :v1, channel)
    end

    test "returns empty list when there are none for a channel" do
      channel = encode(:account_pubkey, <<14::256>>)
      assert [] = Subscriptions.subscribers(:node, :v1, channel)
    end
  end

  describe "subscribed_channels/1" do
    test "returns channels of a subscriber" do
      pid1 = new_pid()
      pid2 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2]) end)

      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid1, :node, :v1, "KeyBlocks")
      channel = encode(:account_pubkey, <<15::256>>)
      assert {:ok, [^channel]} = Subscriptions.subscribe(pid2, :node, :v1, channel)

      assert ["KeyBlocks"] = Subscriptions.subscribed_channels(pid1)
      assert [^channel] = Subscriptions.subscribed_channels(pid2)
    end

    test "returns no channels after subscriber goes DOWN" do
      pid1 = new_pid()
      pid2 = new_pid()

      on_exit(fn -> unsubscribe_all([pid1, pid2]) end)

      assert {:ok, ["KeyBlocks"]} = Subscriptions.subscribe(pid1, :node, :v1, "KeyBlocks")
      assert {:ok, ["MicroBlocks"]} = Subscriptions.subscribe(pid2, :node, :v1, "MicroBlocks")

      assert ["KeyBlocks"] = Subscriptions.subscribed_channels(pid1)
      Process.exit(pid1, :kill)
      assert [] = Subscriptions.subscribed_channels("KeyBlocks")
      assert ["MicroBlocks"] = Subscriptions.subscribed_channels(pid2)
    end
  end

  defp new_pid(), do: Process.spawn(fn -> Process.sleep(3_000) end, [])
end
