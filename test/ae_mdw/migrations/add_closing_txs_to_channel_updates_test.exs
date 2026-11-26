defmodule AeMdw.Migrations.AddClosingTxsToChannelUpdatesTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Migrations.AddClosingTxsToChannelUpdates
  alias AeMdw.Node.Db, as: NodeDb

  import Mock

  require Model

  # priv/migrations isn't compiled in the test env
  unless Code.ensure_loaded?(AddClosingTxsToChannelUpdates) do
    Code.require_file("priv/migrations/20261119160000_add_closing_txs_to_channel_updates.ex")
  end

  test "adds the closing tx of every closed channel to its updates, once" do
    base_txi = Enum.random(900_000_000..999_000_000)
    [mutual_pk, settled_pk, done_pk] = Enum.map(1..3, fn _i -> :crypto.strong_rand_bytes(32) end)
    [mutual_txi, settle_txi, done_txi] = [base_txi + 10, base_txi + 20, base_txi + 30]

    mutual_update = {{100, 0}, {base_txi + 1, -1}}
    settled_update = {{100, 1}, {base_txi + 2, -1}}
    done_update = {{100, 2}, {base_txi + 3, -1}}
    done_close_update = {{110, 0}, {done_txi, -1}}

    channels = [
      Model.channel(index: mutual_pk, updates: [mutual_update]),
      Model.channel(index: settled_pk, updates: [settled_update]),
      Model.channel(index: done_pk, updates: [done_close_update, done_update])
    ]

    rows = [
      {Model.Type, Model.type(index: {:channel_close_mutual_tx, mutual_txi})},
      {Model.InnerType, Model.type(index: {:channel_settle_tx, settle_txi})},
      {Model.Type, Model.type(index: {:channel_close_mutual_tx, done_txi})},
      {Model.Tx, Model.tx(index: mutual_txi, block_index: {110, 1})},
      {Model.Tx, Model.tx(index: settle_txi, block_index: {120, 0})},
      {Model.Tx, Model.tx(index: done_txi, block_index: {110, 0})}
      | Enum.map(channels, &{Model.InactiveChannel, &1})
    ]

    Enum.each(rows, fn {table, record} -> Database.dirty_write(table, record) end)

    on_exit(fn ->
      Enum.each(rows, fn {table, record} -> Database.dirty_delete(table, elem(record, 1)) end)
    end)

    closing_txs = %{
      mutual_txi =>
        {close_mutual_tx(mutual_pk), :channel_close_mutual_tx, :channel_close_mutual_tx},
      settle_txi => {settle_tx(settled_pk), :channel_settle_tx, :ga_meta_tx},
      done_txi => {close_mutual_tx(done_pk), :channel_close_mutual_tx, :channel_close_mutual_tx}
    }

    with_mocks [
      {DbUtil, [:passthrough],
       read_node_tx_details: fn _state, {txi, -1} ->
         {tx, tx_type, wrapper_type} = Map.fetch!(closing_txs, txi)
         {tx, tx_type, <<txi::256>>, wrapper_type, <<0::256>>}
       end}
    ] do
      assert {:ok, 2} = AddClosingTxsToChannelUpdates.run(State.new(), false)
      assert {:ok, 0} = AddClosingTxsToChannelUpdates.run(State.new(), false)
    end

    state = State.new()

    assert {:ok, Model.channel(updates: [{{110, 1}, {^mutual_txi, -1}}, ^mutual_update])} =
             State.get(state, Model.InactiveChannel, mutual_pk)

    assert {:ok, Model.channel(updates: [{{120, 0}, {^settle_txi, -1}}, ^settled_update])} =
             State.get(state, Model.InactiveChannel, settled_pk)

    assert {:ok, Model.channel(updates: [^done_close_update, ^done_update])} =
             State.get(state, Model.InactiveChannel, done_pk)
  end

  test "adds a closing tx behind two wrappers" do
    txi = Enum.random(900_000_000..999_000_000)
    tx_hash = <<txi::256>>
    channel_pk = :crypto.strong_rand_bytes(32)
    update = {{100, 0}, {txi - 1, -1}}

    rows = [
      {Model.InnerType, Model.type(index: {:channel_close_mutual_tx, txi})},
      {Model.Tx, Model.tx(index: txi, id: tx_hash, block_index: {110, 0})},
      {Model.InactiveChannel, Model.channel(index: channel_pk, updates: [update])}
    ]

    Enum.each(rows, fn {table, record} -> Database.dirty_write(table, record) end)

    on_exit(fn ->
      Enum.each(rows, fn {table, record} -> Database.dirty_delete(table, elem(record, 1)) end)
    end)

    {:ok, paying_for_aetx} =
      :aec_paying_for_tx.new(%{
        payer_id: :aeser_id.create(:account, <<2::256>>),
        nonce: 1,
        fee: 2,
        tx: :aetx_sign.new(close_mutual_aetx(channel_pk), [])
      })

    {:ok, ga_meta_aetx} =
      :aega_meta_tx.new(%{
        ga_id: :aeser_id.create(:account, <<3::256>>),
        auth_data: "auth-data",
        abi_version: 1,
        gas: 2,
        gas_price: 3,
        fee: 4,
        tx: :aetx_sign.new(paying_for_aetx, [])
      })

    {:ga_meta_tx, ga_meta_tx} = :aetx.specialize_type(ga_meta_aetx)

    with_mocks [
      {NodeDb, [:passthrough],
       get_tx_data: fn ^tx_hash -> {<<0::256>>, :ga_meta_tx, :signed_tx, ga_meta_tx} end}
    ] do
      assert {:ok, 1} = AddClosingTxsToChannelUpdates.run(State.new(), false)
    end

    assert {:ok, Model.channel(updates: [{{110, 0}, {^txi, -1}}, ^update])} =
             State.get(State.new(), Model.InactiveChannel, channel_pk)
  end

  defp close_mutual_tx(channel_pk) do
    {:channel_close_mutual_tx, tx} = channel_pk |> close_mutual_aetx() |> :aetx.specialize_type()

    tx
  end

  defp close_mutual_aetx(channel_pk) do
    {:ok, aetx} =
      :aesc_close_mutual_tx.new(%{
        channel_id: :aeser_id.create(:channel, channel_pk),
        from_id: :aeser_id.create(:account, <<1::256>>),
        initiator_amount_final: 1,
        responder_amount_final: 2,
        ttl: 3,
        fee: 4,
        nonce: 5
      })

    aetx
  end

  defp settle_tx(channel_pk) do
    {:ok, aetx} =
      :aesc_settle_tx.new(%{
        channel_id: :aeser_id.create(:channel, channel_pk),
        from_id: :aeser_id.create(:account, <<1::256>>),
        initiator_amount_final: 1,
        responder_amount_final: 2,
        fee: 3,
        nonce: 4
      })

    {:channel_settle_tx, tx} = :aetx.specialize_type(aetx)

    tx
  end
end
