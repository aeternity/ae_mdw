defmodule AeMdw.Db.Channels do
  @moduledoc false

  alias AeMdw.Blocks
  alias AeMdw.Db.ChannelCloseMutation
  alias AeMdw.Db.ChannelOpenMutation
  alias AeMdw.Db.ChannelSpendMutation
  alias AeMdw.Db.ChannelUpdateMutation
  alias AeMdw.Db.Mutation
  alias AeMdw.Node

  @typep bi_txi() :: Blocks.bi_txi()

  @spec close_mutual_mutations(bi_txi(), Node.tx()) :: [Mutation.t()]
  def close_mutual_mutations(bi_txi, tx) do
    channel_pk = :aesc_close_mutual_tx.channel_pubkey(tx)

    release_amount =
      :aesc_close_mutual_tx.initiator_amount_final(tx) +
        :aesc_close_mutual_tx.responder_amount_final(tx)

    [
      ChannelCloseMutation.new(channel_pk, bi_txi, release_amount)
    ]
  end

  @spec close_solo_mutations(bi_txi(), Node.tx()) :: [Mutation.t()]
  def close_solo_mutations(bi_txi, tx) do
    channel_pk = :aesc_close_solo_tx.channel_pubkey(tx)

    [
      ChannelUpdateMutation.new(channel_pk, bi_txi)
    ]
  end

  @spec set_delegates_mutations(bi_txi(), Node.tx()) :: [Mutation.t()]
  def set_delegates_mutations(bi_txi, tx) do
    channel_pk = :aesc_set_delegates_tx.channel_pubkey(tx)

    [
      ChannelUpdateMutation.new(channel_pk, bi_txi)
    ]
  end

  @spec force_progress_mutations(bi_txi(), Node.tx()) :: [Mutation.t()]
  def force_progress_mutations(bi_txi, tx) do
    channel_pk = :aesc_force_progress_tx.channel_pubkey(tx)

    [
      ChannelUpdateMutation.new(channel_pk, bi_txi)
    ]
  end

  @spec slash_mutations(bi_txi(), Node.tx()) :: [Mutation.t()]
  def slash_mutations(bi_txi, tx) do
    channel_pk = :aesc_slash_tx.channel_pubkey(tx)

    [
      ChannelUpdateMutation.new(channel_pk, bi_txi)
    ]
  end

  @spec settle_mutations(bi_txi(), Node.tx()) :: [Mutation.t()]
  def settle_mutations(bi_txi, tx) do
    channel_pk = :aesc_settle_tx.channel_pubkey(tx)

    %{"initiator_amount_final" => initiator_amount, "responder_amount_final" => responder_amount} =
      :aesc_settle_tx.for_client(tx)

    [
      ChannelCloseMutation.new(channel_pk, bi_txi, initiator_amount + responder_amount)
    ]
  end

  @spec open_mutations(bi_txi(), Node.tx()) :: [Mutation.t()]
  def open_mutations(bi_txi, tx), do: [ChannelOpenMutation.new(bi_txi, tx)]

  @spec deposit_mutations(bi_txi(), Node.tx()) :: [Mutation.t()]
  def deposit_mutations(bi_txi, tx) do
    channel_pk = :aesc_deposit_tx.channel_pubkey(tx)

    [
      ChannelSpendMutation.new(channel_pk, bi_txi, :aesc_deposit_tx.amount(tx))
    ]
  end

  @spec withdraw_mutations(bi_txi(), Node.tx()) :: [Mutation.t()]
  def withdraw_mutations(bi_txi, tx) do
    channel_pk = :aesc_withdraw_tx.channel_pubkey(tx)

    [
      ChannelSpendMutation.new(channel_pk, bi_txi, -:aesc_withdraw_tx.amount(tx))
    ]
  end
end
