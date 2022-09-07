defmodule AeMdw.Db.ChannelCloseMutation do
  @moduledoc """
  Increases channels_closed stat and refund locked AE.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:channel_pk, :bi_txi, :released_amount]

  @opaque t() :: %__MODULE__{
            channel_pk: Db.pubkey(),
            bi_txi: Blocks.bi_txi(),
            released_amount: non_neg_integer()
          }

  @spec new(Db.pubkey(), Blocks.bi_txi(), non_neg_integer()) :: t()
  def new(channel_pk, bi_txi, released_amount),
    do: %__MODULE__{channel_pk: channel_pk, bi_txi: bi_txi, released_amount: released_amount}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{channel_pk: channel_pk, released_amount: released_amount}, state) do
    channel =
      Model.channel(active: active_height, amount: old_amount) =
      State.fetch!(state, Model.ActiveChannel, channel_pk)

    state
    |> State.inc_stat(:channels_closed)
    |> State.inc_stat(:locked_in_channels, -released_amount)
    |> State.delete(Model.ActiveChannel, channel_pk)
    |> State.delete(Model.ActiveChannelActivation, {active_height, channel_pk})
    |> State.put(
      Model.InactiveChannel,
      Model.channel(channel, amount: old_amount - released_amount)
    )
  end
end
