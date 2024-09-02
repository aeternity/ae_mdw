defmodule AeMdw.Db.BlockStatisticsMutation do
  @moduledoc """
  Creates statistics relevant to block-specific situtations.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:time]

  @opaque t() :: %__MODULE__{
            time: Blocks.time()
          }

  @spec new(Blocks.time()) :: t()
  def new(time), do: %__MODULE__{time: time}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{time: time}, state) do
    case State.get_stat(state, :micro_block_names_activated, 0) do
      0 ->
        state

      count ->
        state
        |> Stats.increment_statistics(:names_activated, time, count)
        |> State.clear_stat(:micro_block_names_activated)
    end
  end
end
