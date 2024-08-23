defmodule AeMdw.Db.BlockDificultyMutation do
  @moduledoc """
  Creates a statistic record for the block dificulty.
  """
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats

  require Model

  @derive Mutation
  defstruct [:time, :dificulty]

  @opaque t() :: %__MODULE__{
            time: Blocks.time(),
            dificulty: integer()
          }

  @spec new(Blocks.time(), integer()) :: t()
  def new(time, dificulty), do: %__MODULE__{time: time, dificulty: dificulty}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{dificulty: dificulty}, state) do
    dificulty
    |> Stats.time_intervals()
    |> Enum.reduce(state, fn {interval_by, interval_start}, state ->
      index = {:block_dificulty, interval_by, interval_start}

      insert_stat(state, index, dificulty)
    end)
  end

  defp insert_stat(state, index, dificulty) do
    State.put(
      state,
      Model.Statistic,
      Model.statistic(index: index, count: dificulty)
    )
  end
end
