defmodule AeMdw.Db.StatisticsMutation do
  @moduledoc """
  Increments the statistics count.
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
      State.update(
        state,
        Model.Statistic,
        statistic_index,
        fn Model.statistic(count: count) = statistic ->
          Model.statistic(statistic, count: count + statistic_increment)
        end,
        Model.statistic(index: statistic_index, count: 0)
      )
    end)
  end
end
