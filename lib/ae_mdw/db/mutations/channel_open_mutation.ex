defmodule AeMdw.Db.ChannelOpenMutation do
  @moduledoc """
  Increases channels_opened stat.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:bi_txi_idx, :tx]

  @typep bi_txi_idx() :: Blocks.bi_txi_idx()
  @opaque t() :: %__MODULE__{
            bi_txi_idx: bi_txi_idx(),
            tx: Node.tx()
          }

  @spec new(bi_txi_idx(), Node.tx()) :: t()
  def new(bi_txi_idx, tx), do: %__MODULE__{bi_txi_idx: bi_txi_idx, tx: tx}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{bi_txi_idx: {{height, _mbi}, _txi_idx} = bi_txi_idx, tx: tx}, state) do
    initiator_amount = :aesc_create_tx.initiator_amount(tx)
    responder_amount = :aesc_create_tx.responder_amount(tx)
    amount = initiator_amount + responder_amount
    channel_pk = :aesc_create_tx.channel_pubkey(tx)

    channel =
      Model.channel(
        index: channel_pk,
        active: height,
        initiator: :aesc_create_tx.initiator_pubkey(tx),
        responder: :aesc_create_tx.responder_pubkey(tx),
        state_hash: :aesc_create_tx.state_hash(tx),
        amount: amount,
        updates: [bi_txi_idx]
      )

    activation = Model.activation(index: {height, channel_pk})

    state
    |> State.inc_stat(:channels_opened)
    |> State.inc_stat(:locked_in_channels, amount)
    |> State.put(Model.ActiveChannel, channel)
    |> State.put(Model.ActiveChannelActivation, activation)
  end
end
