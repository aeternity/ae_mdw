defmodule AeMdw.Db.ChannelSpendMutation do
  @moduledoc """
  Logs withdraws/deposists from channels.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:channel_pk, :bi_txi_idx, :amount]

  @opaque t() :: %__MODULE__{
            channel_pk: Db.pubkey(),
            bi_txi_idx: Blocks.bi_txi_idx(),
            amount: integer()
          }

  @spec new(Db.pubkey(), Blocks.bi_txi_idx(), integer()) :: t()
  def new(channel_pk, bi_txi_idx, amount),
    do: %__MODULE__{channel_pk: channel_pk, bi_txi_idx: bi_txi_idx, amount: amount}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{channel_pk: channel_pk, bi_txi_idx: bi_txi_idx, amount: amount}, state) do
    state
    |> State.inc_stat(:locked_in_channels, amount)
    |> State.update!(Model.ActiveChannel, channel_pk, fn Model.channel(
                                                           amount: old_amount,
                                                           updates: updates
                                                         ) = channel ->
      Model.channel(channel, amount: old_amount + amount, updates: [bi_txi_idx | updates])
    end)
  end
end
