defmodule AeMdw.Migrations.AddActiveChannels do
  @moduledoc """
  Add active channels info to Model.ActiveChannels and ActiveChannelActivation tables.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()
    state = State.new()

    {active_channels, inactive_channels} =
      [
        type_txs(state, :channel_create_tx),
        type_txs(state, :channel_deposit_tx),
        type_txs(state, :channel_withdraw_tx),
        type_txs(state, :channel_force_progress_tx),
        type_txs(state, :channel_offchain_tx),
        type_txs(state, :channel_set_delegates_tx),
        type_txs(state, :channel_slash_tx),
        type_txs(state, :channel_close_solo_tx),
        type_txs(state, :channel_close_mutual_tx),
        type_txs(state, :channel_settle_tx)
      ]
      |> Collection.merge(:forward)
      |> Stream.map(fn {txi, tx_type} ->
        Model.tx(id: tx_hash, block_index: block_index) = State.fetch!(state, Model.Tx, txi)

        {{block_index, txi}, tx_type, core_tx(tx_hash)}
      end)
      |> Enum.reduce({%{}, %{}}, fn
        {{{height, _mbi}, _txi} = bi_txi, :channel_create_tx, tx},
        {active_channels, inactive_channels} ->
          initiator_amount = :aesc_create_tx.initiator_amount(tx)
          responder_amount = :aesc_create_tx.responder_amount(tx)
          amount = initiator_amount + responder_amount
          channel_pk = :aesc_create_tx.channel_pubkey(tx)

          channel =
            Model.channel(
              index: channel_pk,
              active: height,
              initiator: :aesc_create_tx.initiator_pubkey(tx),
              responder: :aesc_create_tx.initiator_pubkey(tx),
              state_hash: :aesc_create_tx.state_hash(tx),
              amount: amount,
              updates: [bi_txi]
            )

          {Map.put(active_channels, channel_pk, channel), inactive_channels}

        {bi_txi, :channel_deposit_tx, tx}, {active_channels, inactive_channels} ->
          channel_pk = :aesc_deposit_tx.channel_pubkey(tx)
          amount = :aesc_deposit_tx.amount(tx)

          active_channels =
            Map.update!(active_channels, channel_pk, fn Model.channel(
                                                          amount: old_amount,
                                                          updates: updates
                                                        ) = channel ->
              Model.channel(channel, amount: old_amount + amount, updates: [bi_txi | updates])
            end)

          {active_channels, inactive_channels}

        {bi_txi, :channel_withdraw_tx, tx}, {active_channels, inactive_channels} ->
          channel_pk = :aesc_withdraw_tx.channel_pubkey(tx)
          amount = :aesc_withdraw_tx.amount(tx)

          active_channels =
            Map.update!(active_channels, channel_pk, fn Model.channel(
                                                          amount: old_amount,
                                                          updates: updates
                                                        ) = channel ->
              Model.channel(channel, amount: old_amount - amount, updates: [bi_txi | updates])
            end)

          {active_channels, inactive_channels}

        {bi_txi, :channel_close_solo_tx, tx}, {active_channels, inactive_channels} ->
          channel_pk = :aesc_close_solo_tx.channel_pubkey(tx)

          active_channels =
            Map.update!(active_channels, channel_pk, fn Model.channel(updates: updates) = channel ->
              Model.channel(channel, updates: [bi_txi | updates])
            end)

          {active_channels, inactive_channels}

        {bi_txi, :channel_force_progress_tx, tx}, {active_channels, inactive_channels} ->
          channel_pk = :aesc_force_progress_tx.channel_pubkey(tx)
          channel = Model.channel(updates: updates) = Map.fetch!(active_channels, channel_pk)
          new_channel = Model.channel(channel, updates: [bi_txi | updates])

          {Map.put(active_channels, channel_pk, new_channel), inactive_channels}

        {bi_txi, :channel_offchain_tx, tx}, {active_channels, inactive_channels} ->
          channel_pk = :aesc_slash_tx.channel_pubkey(tx)
          channel = Model.channel(updates: updates) = Map.fetch!(active_channels, channel_pk)
          new_channel = Model.channel(channel, updates: [bi_txi | updates])

          {Map.put(active_channels, channel_pk, new_channel), inactive_channels}

        {bi_txi, :channel_set_delegates_tx, tx}, {active_channels, inactive_channels} ->
          channel_pk = :aesc_set_delegates_tx.channel_pubkey(tx)
          channel = Model.channel(updates: updates) = Map.fetch!(active_channels, channel_pk)
          new_channel = Model.channel(channel, updates: [bi_txi | updates])

          {Map.put(active_channels, channel_pk, new_channel), inactive_channels}

        {bi_txi, :channel_slash_tx, tx}, {active_channels, inactive_channels} ->
          channel_pk = :aesc_slash_tx.channel_pubkey(tx)
          channel = Model.channel(updates: updates) = Map.fetch!(active_channels, channel_pk)
          new_channel = Model.channel(channel, updates: [bi_txi | updates])

          {Map.put(active_channels, channel_pk, new_channel), inactive_channels}

        {bi_txi, :channel_close_mutual_tx, tx}, {active_channels, inactive_channels} ->
          channel_pk = :aesc_close_mutual_tx.channel_pubkey(tx)
          channel = Model.channel(updates: updates) = Map.fetch!(active_channels, channel_pk)
          new_channel = Model.channel(channel, amount: 0, updates: [bi_txi | updates])

          {Map.delete(active_channels, channel_pk),
           Map.put(inactive_channels, channel_pk, new_channel)}

        {bi_txi, :channel_settle_tx, tx}, {active_channels, inactive_channels} ->
          channel_pk = :aesc_settle_tx.channel_pubkey(tx)
          channel = Model.channel(updates: updates) = Map.fetch!(active_channels, channel_pk)
          new_channel = Model.channel(channel, amount: 0, updates: [bi_txi | updates])

          {Map.delete(active_channels, channel_pk),
           Map.put(inactive_channels, channel_pk, new_channel)}
      end)

    duration = DateTime.diff(DateTime.utc_now(), begin)

    active_mutations =
      Enum.flat_map(active_channels, fn {channel_pk, channel} ->
        Model.channel(active: active_height) = channel
        activation = Model.activation(index: {active_height, channel_pk})

        [
          WriteMutation.new(Model.ActiveChannel, channel),
          WriteMutation.new(Model.ActiveChannelActivation, activation)
        ]
      end)

    inactive_mutations =
      Enum.map(inactive_channels, fn {_channel_pk, channel} ->
        WriteMutation.new(Model.InactiveChannel, channel)
      end)

    mutations = active_mutations ++ inactive_mutations

    State.commit(state, mutations)

    {:ok, {div(length(active_mutations), 2) + length(inactive_mutations), duration}}
  end

  defp type_txs(state, type) do
    state
    |> Collection.stream(Model.Type, {type, 0})
    |> Stream.take_while(&match?({^type, _txi}, &1))
    |> Stream.map(fn {^type, txi} -> {txi, type} end)
  end

  defp core_tx(tx_hash) do
    {_mod, tx} =
      tx_hash
      |> :aec_db.get_signed_tx()
      |> :aetx_sign.tx()
      |> :aetx.specialize_callback()

    tx
  end
end
