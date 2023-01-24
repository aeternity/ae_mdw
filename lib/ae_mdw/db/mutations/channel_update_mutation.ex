defmodule AeMdw.Db.ChannelUpdateMutation do
  @moduledoc """
  Adds a new block_index_txi to the channel list of updates.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:channel_pk, :bi_txi_idx]

  @opaque t() :: %__MODULE__{
            channel_pk: Db.pubkey(),
            bi_txi_idx: Blocks.bi_txi_idx()
          }

  @spec new(Db.pubkey(), Blocks.bi_txi_idx()) :: t()
  def new(channel_pk, bi_txi_idx), do: %__MODULE__{channel_pk: channel_pk, bi_txi_idx: bi_txi_idx}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{channel_pk: channel_pk, bi_txi_idx: bi_txi_idx}, state) do
    State.update!(state, Model.ActiveChannel, channel_pk, fn Model.channel(updates: updates) =
                                                               channel ->
      Model.channel(channel, updates: [bi_txi_idx | updates])
    end)
  end
end
