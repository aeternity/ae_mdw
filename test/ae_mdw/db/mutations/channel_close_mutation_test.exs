defmodule AeMdw.Db.ChannelCloseMutationTest do
  use ExUnit.Case, async: true

  alias AeMdw.Db.ChannelCloseMutation
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State

  require Model

  test "moves the channel to the inactive ones with the closing tx as its last update" do
    channel_pk = :crypto.strong_rand_bytes(32)
    open_update = {{10, 0}, {100, -1}}
    close_update = {{20, 1}, {200, -1}}

    channel =
      Model.channel(index: channel_pk, active: 10, amount: 30, updates: [open_update])

    state =
      NullStore.new()
      |> MemStore.new()
      |> State.new()
      |> State.put(Model.ActiveChannel, channel)
      |> State.put(Model.ActiveChannelActivation, Model.activation(index: {10, channel_pk}))

    state =
      ChannelCloseMutation.execute(ChannelCloseMutation.new(channel_pk, close_update, 30), state)

    refute State.exists?(state, Model.ActiveChannel, channel_pk)

    assert {:ok, Model.channel(amount: 0, updates: [^close_update, ^open_update])} =
             State.get(state, Model.InactiveChannel, channel_pk)

    assert State.exists?(state, Model.InactiveChannelActivation, {10, channel_pk})
  end
end
