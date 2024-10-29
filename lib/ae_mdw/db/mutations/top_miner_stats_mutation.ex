defmodule AeMdw.Db.TopMinerStatsMutation do
  @moduledoc """
  Increments the top miners stats.
  """

  alias AeMdw.Collection
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
      kb =
        Collection.generate_key_boundary(
          {interval_by, interval_start, Collection.integer(), Collection.binary()}
        )

      state
      |> Collection.stream(Model.TopMinerStats, :backward, kb, nil)
      |> Stream.filter(fn {_interval_by, _interval_start, _count, bpk} ->
        bpk == beneficiary_pk
      end)
      |> tap(&IO.inspect(Enum.count(&1)))
      |> Enum.at(0, :none)
      |> case do
        {^interval_by, ^interval_start, count, ^beneficiary_pk} ->
          IO.inspect("updating")

          state
          |> State.delete(
            Model.TopMinerStats,
            {interval_by, interval_start, count, beneficiary_pk}
          )
          |> State.put(
            Model.TopMinerStats,
            Model.top_miner_stats(index: {interval_by, interval_start, count + 1, beneficiary_pk})
          )

        :none ->
          IO.inspect("inserting missing")

          State.put(
            state,
            Model.TopMinerStats,
            Model.top_miner_stats(index: {interval_by, interval_start, 1, beneficiary_pk})
          )
      end
    end)
  end
end
