defmodule AeMdw.Db.StatisticsMutation do
  @moduledoc """
  Increments the statistics count.
  """

  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Sync.Stats

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:statistics]

  @typep statistics() :: [{Model.statistic_index(), pos_integer()}]
  @opaque t() :: %__MODULE__{
            statistics: statistics()
          }

  @spec new(statistics()) :: t()
  def new(statistics), do: %__MODULE__{statistics: statistics}

  @doc """
  Replaces the statistics mutations of a flat list with one at the end that
  updates each statistic once.
  """
  @spec merge([Mutation.t()]) :: [Mutation.t()]
  def merge(mutations) do
    case Enum.split_with(mutations, &is_struct(&1, __MODULE__)) do
      {[], _other_mutations} ->
        mutations

      {statistics_mutations, other_mutations} ->
        statistics =
          statistics_mutations
          |> Enum.map(fn %__MODULE__{statistics: statistics} -> statistics end)
          |> Stats.sum_statistics()

        other_mutations ++ [new(statistics)]
    end
  end

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
