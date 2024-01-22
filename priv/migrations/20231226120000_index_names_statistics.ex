defmodule AeMdw.Migrations.IndexNameStatistics do
  @moduledoc """
  Index active names statistics.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, from_start?) do
    case State.prev(state, Model.DeltaStat, nil) do
      {:ok, top_height} -> run(state, from_start?, top_height)
      :none -> {:ok, 0}
    end
  end

  defp run(state, _from_start?, top_height) do
    count =
      0..top_height
      |> Stream.map(&State.fetch!(state, Model.DeltaStat, &1))
      |> Stream.reject(&match?(Model.delta_stat(names_activated: 0), &1))
      |> Stream.map(fn Model.delta_stat(index: height, names_activated: names_activated) ->
        {:ok, header} = :aec_chain.get_key_header_by_height(height)

        [day_interval, week_interval, month_interval] =
          header
          |> :aec_headers.time_in_msecs()
          |> Stats.time_intervals()

        {day_interval, week_interval, month_interval, names_activated}
      end)
      |> Stream.concat([{:end, :end, :end, 0}])
      |> Stream.transform({nil, nil, nil}, fn {day_interval, week_interval, month_interval,
                                               names_activated},
                                              {day_acc, week_acc, month_acc} ->
        {day_mutations, new_day_interval} =
          process_interval(day_interval, names_activated, day_acc)

        {week_mutations, new_week_interval} =
          process_interval(week_interval, names_activated, week_acc)

        {month_mutations, new_month_interval} =
          process_interval(month_interval, names_activated, month_acc)

        {day_mutations ++ week_mutations ++ month_mutations,
         {new_day_interval, new_week_interval, new_month_interval}}
      end)
      |> Stream.chunk_every(1_000)
      |> Stream.map(fn mutations ->
        _new_state = State.commit_db(state, mutations)

        length(mutations)
      end)
      |> Enum.sum()

    {:ok, count}
  end

  defp process_interval(new_interval, count, nil), do: {[], {new_interval, count}}

  defp process_interval(:end, 0, {{interval_by, interval_start}, count}) do
    index = {:names_activated, interval_by, interval_start}
    mutation = WriteMutation.new(Model.Statistic, Model.statistic(index: index, count: count))

    {[mutation], nil}
  end

  defp process_interval(interval, count, {interval, old_count}) do
    {[], {interval, old_count + count}}
  end

  defp process_interval(interval, count, {old_interval, old_count}) do
    {[mutation], nil} = process_interval(:end, 0, {old_interval, old_count})

    {[mutation], {interval, count}}
  end
end
