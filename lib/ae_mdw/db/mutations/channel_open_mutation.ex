defmodule AeMdw.Db.ChannelOpenMutation do
  @moduledoc """
  Increases channels_opened stat.
  """

  alias AeMdw.Db.State
  alias AeMdw.Node

  @derive AeMdw.Db.Mutation
  defstruct [:tx]

  @opaque t() :: %__MODULE__{
            tx: Node.aetx()
          }

  @spec new(Node.aetx()) :: t()
  def new(tx), do: %__MODULE__{tx: tx}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{tx: tx}, state) do
    initiator_amount = :aesc_create_tx.initiator_amount(tx)
    responder_amount = :aesc_create_tx.responder_amount(tx)

    state
    |> State.inc_stat(:channels_opened)
    |> State.inc_stat(:locked_in_channels, initiator_amount + responder_amount)
  end
end
