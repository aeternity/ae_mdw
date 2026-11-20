defmodule AeMdw.Db.TotalStatisticsMutation do
  @moduledoc """
  Updates the statistics cumulatively instead of keeping it as deltas
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
  Replaces the total statistics mutations of a flat list with one at the end
  that updates each statistic once.
  """
  @spec merge([Mutation.t()]) :: [Mutation.t()]
  def merge(mutations) do
    case Enum.split_with(mutations, &is_struct(&1, __MODULE__)) do
      {[], _other_mutations} ->
        mutations

      {statistics_mutations, other_mutations} ->
        # sorted, since a missing day starts from the previous day's count
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
