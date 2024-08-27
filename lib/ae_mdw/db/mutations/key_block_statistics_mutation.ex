defmodule AeMdw.Db.KeyBlockStatsMutation do
  @moduledoc """
  Creates a statistic records for key blocks.
  """
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats

  require Model

  @derive Mutation
  defstruct [:time, :difficulty]

  @opaque t() :: %__MODULE__{
            time: Blocks.time(),
            difficulty: integer()
          }

  @spec new(Blocks.time(), integer()) :: t()
  def new(time, difficulty), do: %__MODULE__{time: time, difficulty: difficulty}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{time: time, difficulty: difficulty}, state) do
    time
    |> Stats.time_intervals()
    |> Enum.reduce(state, fn {interval_by, interval_start}, state ->
      index = {:blocks_difficulty, interval_by, interval_start}

      average_statistic(state, index, difficulty)
    end)
  end

  defp average_statistic(state, index, new_difficulty) do
    State.update(
      state,
      Model.Statistic,
      index,
      fn
        Model.statistic(count: nil) = statistic ->
          Model.statistic(statistic, count: new_difficulty)

        Model.statistic(count: old_difficulty) = statistic ->
          Model.statistic(statistic, count: round((old_difficulty + new_difficulty) / 2))
      end
    )
  end
end
