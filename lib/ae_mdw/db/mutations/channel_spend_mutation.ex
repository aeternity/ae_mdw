defmodule AeMdw.Db.ChannelSpendMutation do
  @moduledoc """
  Logs withdraws/deposists from channels.
  """

  alias AeMdw.Db.State

  @derive AeMdw.Db.Mutation
  defstruct [:amount]

  @opaque t() :: %__MODULE__{amount: integer()}

  @spec new(integer()) :: t()
  def new(amount), do: %__MODULE__{amount: amount}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{amount: amount}, state) do
    State.inc_stat(state, :locked_in_channels, amount)
  end
end
