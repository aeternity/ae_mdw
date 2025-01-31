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
    Enum.reduce(statistics, state, fn {{tag, interval_by, _interval_start} = statistic_index,
                                       statistic_increment},
                                      state ->
      prev_stat_count =
        state
        |> State.prev(Model.Statistic, statistic_index)
        |> case do
          {:ok, {^tag, ^interval_by, _prev_interval_start} = index} ->
            Model.statistic(count: count) = State.fetch!(state, Model.Statistic, index)
            count

          {:ok, _other_statistic} ->
            0

          :none ->
            0
        end

      State.update(
        state,
        Model.Statistic,
        statistic_index,
        fn Model.statistic(count: count) = statistic ->
          Model.statistic(statistic, count: count + statistic_increment)
        end,
        Model.statistic(index: statistic_index, count: prev_stat_count)
      )
    end)
  end
end
