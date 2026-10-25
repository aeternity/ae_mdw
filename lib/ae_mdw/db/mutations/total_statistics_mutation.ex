defmodule AeMdw.Db.TotalStatisticsMutation do
  @moduledoc """
  Updates the statistics cumulatively instead of keeping it as deltas
  """

  alias AeMdw.Db.State
  alias AeMdw.Db.Model

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:statistics]

  @typep statistics() :: [{Model.statistic_index(), pos_integer()}]
  @opaque t() :: %__MODULE__{
            statistics: statistics()
          }

  @spec new(statistics()) :: t()
  def new(statistics), do: %__MODULE__{statistics: statistics}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{statistics: statistics}, state) do
    Enum.reduce(statistics, state, fn {statistic_index, statistic_increment}, state ->
      Model.statistic(count: count) =
        statistic =
        case State.get(state, Model.Statistic, statistic_index) do
          {:ok, statistic} ->
            statistic

          :not_found ->
            Model.statistic(index: statistic_index, count: prev_count(state, statistic_index))
        end

      State.put(
        state,
        Model.Statistic,
        Model.statistic(statistic, count: count + statistic_increment)
      )
    end)
  end

  defp prev_count(state, {tag, interval_by, _interval_start} = statistic_index) do
    case State.prev(state, Model.Statistic, statistic_index) do
      {:ok, {^tag, ^interval_by, _prev_interval_start} = index} ->
        Model.statistic(count: count) = State.fetch!(state, Model.Statistic, index)
        count

      {:ok, _other_statistic} ->
        0

      :none ->
        0
    end
  end
end
