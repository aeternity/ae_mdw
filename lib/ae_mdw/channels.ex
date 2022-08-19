defmodule AeMdw.Channels do
  @moduledoc """
  Main channels module.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.ChannelCloseMutation
  alias AeMdw.Db.ChannelOpenMutation
  alias AeMdw.Db.ChannelSpendMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node
  alias AeMdw.Txs

  require Model

  @typep state() :: State.t()
  @type closing_type() ::
          :channel_close_solo_tx
          | :channel_close_mutual_tx
          | :channel_settle_tx

  @spec close_mutation(closing_type(), Node.aetx()) :: ChannelCloseMutation.t()
  def close_mutation(tx_type, tx), do: ChannelCloseMutation.new(tx_type, tx)

  @spec open_mutation(Node.aetx()) :: ChannelOpenMutation.t()
  def open_mutation(tx), do: ChannelOpenMutation.new(tx)

  @spec deposit_mutation(Node.aetx()) :: ChannelSpendMutation.t()
  def deposit_mutation(tx), do: ChannelSpendMutation.new(:aesc_deposit_tx.amount(tx))

  @spec withdraw_mutation(Node.aetx()) :: ChannelSpendMutation.t()
  def withdraw_mutation(tx), do: ChannelSpendMutation.new(-:aesc_withdraw_tx.amount(tx))

  @spec channels_opened_count(state(), Txs.txi(), Txs.txi()) :: non_neg_integer()
  def channels_opened_count(state, from_txi, next_txi),
    do: type_count(state, :channel_create_tx, from_txi, next_txi)

  @spec channels_closed_count(state(), Txs.txi(), Txs.txi()) :: non_neg_integer()
  def channels_closed_count(state, from_txi, next_txi) do
    type_count(state, :channel_close_solo_tx, from_txi, next_txi) +
      type_count(state, :channel_close_mutual_tx, from_txi, next_txi) +
      type_count(state, :channel_settle_tx, from_txi, next_txi)
  end

  defp type_count(state, type, from_txi, next_txi) do
    state
    |> Collection.stream(Model.Type, {type, from_txi})
    |> Stream.take_while(&match?({^type, txi} when txi < next_txi, &1))
    |> Enum.count()
  end
end
