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
  defstruct [:channel_pk, :bi_txi]

  @opaque t() :: %__MODULE__{
            channel_pk: Db.pubkey(),
            bi_txi: Blocks.bi_txi()
          }

  @spec new(Db.pubkey(), Blocks.bi_txi()) :: t()
  def new(channel_pk, bi_txi), do: %__MODULE__{channel_pk: channel_pk, bi_txi: bi_txi}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{channel_pk: channel_pk, bi_txi: bi_txi}, state) do
    State.update!(state, Model.ActiveChannel, channel_pk, fn Model.channel(updates: updates) =
                                                               channel ->
      Model.channel(channel, updates: [bi_txi | updates])
    end)
  end
end
