defmodule AeMdw.Migrations.AddChannelsStats do
  @moduledoc """
  Add channels info to total/delta stats.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @log_freq 1_000

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()
    state = State.new()

    total_gens =
      case Collection.stream(state, Model.DeltaStat, :backward, nil, nil) |> Enum.take(1) do
        [total_gens] -> total_gens
        [] -> 0
      end

    {delta_opened_stats, delta_locked_stats} =
      state
      |> type_txs(:channel_create_tx)
      |> Enum.reduce({Map.new(), Map.new()}, fn Model.tx(block_index: {height, _mbi}, id: tx_hash),
                                                {open_acc, locked_acc} ->
        tx = core_tx(tx_hash)
        initiator_amount = :aesc_create_tx.initiator_amount(tx)
        responder_amount = :aesc_create_tx.responder_amount(tx)

        amount = initiator_amount + responder_amount

        {
          Map.update(open_acc, height, 1, &(&1 + 1)),
          Map.update(locked_acc, height, amount, &(&1 + amount))
        }
      end)

    delta_locked_stats =
      state
      |> type_txs(:channel_deposit_tx)
      |> Enum.reduce(delta_locked_stats, fn Model.tx(block_index: {height, _mbi}, id: tx_hash),
                                            locked_acc ->
        tx = core_tx(tx_hash)
        amount = :aesc_deposit_tx.amount(tx)
        Map.update(locked_acc, height, amount, &(&1 + amount))
      end)

    delta_locked_stats =
      state
      |> type_txs(:channel_withdraw_tx)
      |> Enum.reduce(delta_locked_stats, fn Model.tx(block_index: {height, _mbi}, id: tx_hash),
                                            locked_acc ->
        tx = core_tx(tx_hash)
        amount = :aesc_withdraw_tx.amount(tx)
        Map.update(locked_acc, height, -amount, &(&1 - amount))
      end)

    delta_closed_stats =
      state
      |> type_txs(:channel_close_solo_tx)
      |> Enum.reduce(Map.new(), fn Model.tx(block_index: {height, _mbi}), closed_acc ->
        Map.update(closed_acc, height, 1, &(&1 + 1))
      end)

    {delta_closed_stats, delta_locked_stats} =
      state
      |> type_txs(:channel_close_mutual_tx)
      |> Enum.reduce({delta_closed_stats, delta_locked_stats}, fn Model.tx(
                                                                    block_index: {height, _mbi},
                                                                    id: tx_hash
                                                                  ),
                                                                  {closed_acc, locked_acc} ->
        tx = core_tx(tx_hash)

        amount =
          :aesc_close_mutual_tx.initiator_amount_final(tx) +
            :aesc_close_mutual_tx.responder_amount_final(tx)

        {
          Map.update(closed_acc, height, 1, &(&1 + 1)),
          Map.update(locked_acc, height, -amount, &(&1 - amount))
        }
      end)

    {delta_closed_stats, delta_locked_stats} =
      state
      |> type_txs(:channel_settle_tx)
      |> Enum.reduce({delta_closed_stats, delta_locked_stats}, fn Model.tx(
                                                                    block_index: {height, _mbi},
                                                                    id: tx_hash
                                                                  ),
                                                                  {closed_acc, locked_acc} ->
        tx = core_tx(tx_hash)

        %{
          "initiator_amount_final" => initiator_amount,
          "responder_amount_final" => responder_amount
        } = :aesc_settle_tx.for_client(tx)

        amount = initiator_amount + responder_amount

        {
          Map.update(closed_acc, height, 1, &(&1 + 1)),
          Map.update(locked_acc, height, -amount, &(&1 - amount))
        }
      end)

    IO.inspect([delta_opened_stats, delta_closed_stats, delta_locked_stats], limit: :infinity)

    state
    |> Collection.stream(Model.DeltaStat, nil)
    |> Enum.reduce({0, 0}, fn height, {channels_opened, channels_locked_amount} ->
      delta_opened = Map.get(delta_opened_stats, height, 0)
      delta_closed = Map.get(delta_closed_stats, height, 0)
      delta_locked = Map.get(delta_locked_stats, height, 0)

      new_open = channels_opened + delta_opened - delta_closed
      new_locked = channels_locked_amount + delta_locked

      new_delta_stat =
        state
        |> State.fetch!(Model.DeltaStat, height)
        |> transform_delta_stat()
        |> Model.delta_stat(
          channels_opened: delta_opened,
          channels_closed: delta_closed,
          locked_in_channels: delta_locked
        )

      new_total_stat =
        state
        |> State.fetch!(Model.TotalStat, height + 1)
        |> transform_total_stat()
        |> Model.total_stat(
          open_channels: new_open,
          locked_in_channels: new_locked
        )

      State.commit(
        state,
        [
          WriteMutation.new(Model.DeltaStat, new_delta_stat),
          WriteMutation.new(Model.TotalStat, new_total_stat)
        ]
      )

      if rem(height, @log_freq) == 0, do: IO.puts("Processed #{height} of #{total_gens}")

      {new_open, new_locked}
    end)

    duration = DateTime.diff(DateTime.utc_now(), begin)

    {:ok, {total_gens, duration}}
  end

  defp transform_delta_stat(
         {:delta_stat, height, auctions_started, names_activated, names_expired, names_revoked,
          oracles_registered, oracles_expired, contracts_created, block_reward, dev_reward,
          locked_in_auctions, burned_in_auctions}
       ) do
    Model.delta_stat(
      index: height,
      auctions_started: auctions_started,
      names_activated: names_activated,
      names_expired: names_expired,
      names_revoked: names_revoked,
      oracles_registered: oracles_registered,
      oracles_expired: oracles_expired,
      contracts_created: contracts_created,
      block_reward: block_reward,
      dev_reward: dev_reward,
      burned_in_auctions: burned_in_auctions,
      locked_in_auctions: locked_in_auctions
    )
  end

  defp transform_delta_stat(Model.delta_stat() = delta_stat), do: delta_stat

  defp transform_total_stat(
         {:total_stat, height, block_reward, dev_reward, total_supply, active_auctions,
          active_names, inactive_names, active_oracles, inactive_oracles, contracts,
          locked_in_auctions, burned_in_auctions}
       ) do
    Model.total_stat(
      index: height,
      block_reward: block_reward,
      dev_reward: dev_reward,
      total_supply: total_supply,
      active_auctions: active_auctions,
      active_names: active_names,
      inactive_names: inactive_names,
      active_oracles: active_oracles,
      inactive_oracles: inactive_oracles,
      contracts: contracts,
      burned_in_auctions: burned_in_auctions,
      locked_in_auctions: locked_in_auctions
    )
  end

  defp transform_total_stat(Model.total_stat() = total_stat), do: total_stat

  defp type_txs(state, type) do
    state
    |> Collection.stream(Model.Type, {type, 0})
    |> Stream.take_while(&match?({^type, _txi}, &1))
    |> Stream.map(fn {^type, txi} -> State.fetch!(state, Model.Tx, txi) end)
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
