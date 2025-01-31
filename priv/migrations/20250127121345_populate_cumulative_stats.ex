defmodule AeMdw.Migrations.PopulateCumulativeStats do
  @moduledoc """
  This migration populates the cumulative statistics table from the transaction statistics table. It can be run multiple times without any side effects.
  """
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Collection
  alias AeMdw.Db.CumulativeStatisticsMutation
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.Model

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    old_kb =
      Collection.generate_key_boundary(
        {{:cumulative_transactions, Collection.gen_range(0, "")}, Collection.binary(),
         Collection.integer()}
      )

    mutations_needed =
      state |> Collection.stream(Model.Statistic, :backward, old_kb, nil) |> Enum.to_list()

    delete_mutation = DeleteKeysMutation.new(%{Model.Statistic => mutations_needed})
    state = State.commit_db(state, [delete_mutation])

    kb =
      Collection.generate_key_boundary(
        {{:transactions, Collection.gen_range(0, "")}, Collection.binary(), Collection.integer()}
      )

    Model.Statistic
    |> RocksDbCF.stream(key_boundary: kb, direction: :forward)
    |> Stream.map(fn Model.statistic(
                       index: {{:transactions, tx_type}, interval_by, interval_start},
                       count: count
                     ) ->
      {{{:cumulative_transactions, tx_type}, interval_by, interval_start}, count}
    end)
    |> Stream.chunk_every(1000)
    |> Enum.map(fn statistics ->
      CumulativeStatisticsMutation.new(statistics)
    end)
    |> then(fn mutations ->
      _state = State.commit(state, mutations)

      length(mutations)
    end)
    |> then(&{:ok, &1})
  end
end
