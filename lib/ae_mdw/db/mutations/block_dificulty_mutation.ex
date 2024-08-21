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

      increment_statistic(state, index, dificulty)
    end)
    |> State.clear_stat(:block_dificulty)
  end

  defp increment_statistic(state, index, increment) do
    State.update(
      state,
      Model.Statistic,
      index,
      fn Model.statistic(count: _count) = statistic ->
        Model.statistic(statistic, count: increment)
      end,
      Model.statistic(index: index, count: 0)
    )
  end
end
