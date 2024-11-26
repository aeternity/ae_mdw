defmodule AeMdw.Db.TopMinerStatsMutation do
  @moduledoc """
  Increments the top miners stats.
  """

  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Stats

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:rewards, :time]

  @opaque t() :: %__MODULE__{rewards: IntTransfer.rewards(), time: non_neg_integer()}

  @spec new(IntTransfer.rewards(), non_neg_integer()) :: t()
  def new(rewards, time), do: %__MODULE__{rewards: rewards, time: time}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{rewards: rewards, time: time}, state) do
    Enum.reduce(rewards, state, fn {beneficiary_pk, _reward}, state ->
      increment_top_miners(state, time, beneficiary_pk)
    end)
  end

  defp increment_top_miners(state, time, beneficiary_pk) do
    time
    |> Stats.time_intervals()
    |> Enum.reduce(state, fn {interval_by, interval_start}, state ->
      state
      |> State.get(Model.TopMiner, {interval_by, interval_start, beneficiary_pk})
      |> case do
        {:ok,
         Model.top_miner(
           index: {^interval_by, ^interval_start, ^beneficiary_pk},
           count: count
         )} ->
          state
          |> State.delete(
            Model.TopMinerStats,
            {interval_by, interval_start, count, beneficiary_pk}
          )
          |> State.put(
            Model.TopMinerStats,
            Model.top_miner_stats(index: {interval_by, interval_start, count + 1, beneficiary_pk})
          )
          |> State.put(
            Model.TopMiner,
            Model.top_miner(
              index: {interval_by, interval_start, beneficiary_pk},
              count: count + 1
            )
          )

        :not_found ->
          state
          |> State.put(
            Model.TopMinerStats,
            Model.top_miner_stats(index: {interval_by, interval_start, 1, beneficiary_pk})
          )
          |> State.put(
            Model.TopMiner,
            Model.top_miner(index: {interval_by, interval_start, beneficiary_pk}, count: 1)
          )
      end
    end)
  end
end
