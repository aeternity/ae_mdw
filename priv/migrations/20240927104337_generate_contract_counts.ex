defmodule AeMdw.Migrations.GenerateContractCounts do
  @moduledoc """
    Generate block difficulty statistics.
  """
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.StatisticsMutation
  alias AeMdw.Db.Sync.Stats

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    state
    |> State.prev(Model.Block, nil)
    |> case do
      {:ok, {top_block_height, _}} ->
        {_state, contracts_count_per_block} =
          state
          |> Collection.stream(Model.Block, :backward, nil, nil)
          |> Stream.filter(fn {_height, idx} -> idx == -1 end)
          |> Stream.map(fn {height, idx} ->
            Model.block(hash: hash) = State.fetch!(state, Model.Block, {height, idx})
            block = :aec_db.get_block(hash)
            time = :aec_blocks.time_in_msecs(block)

            contracts_created =
              if height != top_block_height do
                {:ok, Model.delta_stat(contracts_created: contracts_created)} =
                  State.get(state, Model.DeltaStat, height)

                contracts_created
              else
                0
              end

            time
            |> Stats.time_intervals()
            |> Enum.map(fn {interval, interval_start} ->
              {{:contracts, interval, interval_start}, contracts_created}
            end)
            |> StatisticsMutation.new()
          end)
          |> Stream.chunk_every(1000)
          |> Enum.reduce({state, 0}, fn mutations, {acc_state, count} ->
            {
              State.commit_db(acc_state, mutations),
              count + length(mutations)
            }
          end)

        {:ok, contracts_count_per_block}

      :none ->
        {:ok, 0}
    end
  end
end
