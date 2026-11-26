defmodule AeMdw.Migrations.AddClosingTxsToChannelUpdates do
  @moduledoc """
  Adds the channel_close_mutual_tx or channel_settle_tx of every closed channel
  to its updates, which used to leave them out.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Util

  require Model

  @closing_tx_types ~w(channel_close_mutual_tx channel_settle_tx)a

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    added_count =
      for table <- [Model.Type, Model.InnerType],
          tx_type <- @closing_tx_types,
          {^tx_type, txi} <-
            Collection.stream(
              state,
              table,
              :forward,
              {{tx_type, Util.min_int()}, {tx_type, Util.max_int()}},
              nil
            ),
          reduce: 0 do
        added_count -> added_count + add_closing_update(state, txi)
      end

    {:ok, added_count}
  end

  defp add_closing_update(state, txi) do
    {tx, tx_type, _tx_hash, _wrapper_type, _block_hash} =
      DbUtil.read_node_tx_details(state, {txi, -1})

    {tx_type, tx} = unwrap(tx_type, tx)
    channel_pk = channel_pubkey(tx_type, tx)
    Model.tx(block_index: block_index) = State.fetch!(state, Model.Tx, txi)

    case State.get(state, Model.InactiveChannel, channel_pk) do
      {:ok, Model.channel(updates: [{_bi, {last_txi, _idx}} | _rest] = updates) = channel}
      when last_txi < txi ->
        channel = Model.channel(channel, updates: [{block_index, {txi, -1}} | updates])
        _state = State.put(state, Model.InactiveChannel, channel)

        1

      _added_or_missing ->
        0
    end
  end

  # read_node_tx_details/2 unwraps one wrapper only
  defp unwrap(tx_type, tx) when tx_type in [:ga_meta_tx, :paying_for_tx] do
    {inner_type, inner_tx} =
      tx_type |> InnerTx.signed_tx(tx) |> :aetx_sign.tx() |> :aetx.specialize_type()

    unwrap(inner_type, inner_tx)
  end

  defp unwrap(tx_type, tx), do: {tx_type, tx}

  defp channel_pubkey(:channel_close_mutual_tx, tx), do: :aesc_close_mutual_tx.channel_pubkey(tx)
  defp channel_pubkey(:channel_settle_tx, tx), do: :aesc_settle_tx.channel_pubkey(tx)
end
