defmodule AeMdw.Db.LeaderMutation do
  @moduledoc """
    Possibly put the new leaders for a hyperchain
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.Hyperchain

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:height]

  @opaque t() :: %__MODULE__{
            height: Blocks.height()
          }

  @spec new(Blocks.height()) :: t()
  def new(height) do
    %__MODULE__{
      height: height
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{height: height}, state) do
    if new_epoch?(state, height) do
      put_new_leaders(state, height)
    else
      state
    end
  end

  defp new_epoch?(state, height) do
    not State.exists?(state, Model.HyperchainLeaderAtHeight, height)
  end

  defp put_new_leaders(state, height) do
    height
    |> Hyperchain.leaders_for_epoch_at_height()
    |> Enum.reduce(state, fn {height, leader}, state ->
      State.put(
        state,
        Model.HyperchainLeaderAtHeight,
        Model.hyperchain_leader_at_height(index: height, leader: leader)
      )
    end)
  end
end
