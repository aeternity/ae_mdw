defmodule AeMdw.Db.ChannelCloseMutation do
  @moduledoc """
  Increases channels_closed stat and refund locked AE.
  """

  alias AeMdw.Channels
  alias AeMdw.Db.State
  alias AeMdw.Node

  @derive AeMdw.Db.Mutation
  defstruct [:tx_type, :tx]

  @typep tx_type() :: Channels.closing_type()

  @opaque t() :: %__MODULE__{tx_type: tx_type(), tx: Node.aetx()}

  @spec new(tx_type(), Node.aetx()) :: t()
  def new(tx_type, tx), do: %__MODULE__{tx_type: tx_type, tx: tx}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{tx_type: tx_type, tx: tx}, state) do
    state
    |> State.inc_stat(:channels_closed)
    |> State.inc_stat(:locked_in_channels, -released_amount(tx_type, tx))
  end

  defp released_amount(:channel_close_solo_tx, _tx), do: 0

  defp released_amount(:channel_close_mutual_tx, tx) do
    :aesc_close_mutual_tx.initiator_amount_final(tx) +
      :aesc_close_mutual_tx.responder_amount_final(tx)
  end

  defp released_amount(:channel_settle_tx, tx) do
    %{"initiator_amount_final" => initiator_amount, "responder_amount_final" => responder_amount} =
      :aesc_settle_tx.for_client(tx)

    initiator_amount + responder_amount
  end
end
