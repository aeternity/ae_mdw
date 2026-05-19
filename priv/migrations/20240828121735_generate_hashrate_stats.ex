defmodule AeMdw.Migrations.GenerateHashrateStats do
  @moduledoc """
    Generate block hashrate statistics.
  """
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.StatisticsMutation
  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Node

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {_state, block_hashrates_added} =
      state
      |> Collection.stream(Model.Block, :backward, nil, nil)
      |> Stream.filter(fn {_height, idx} -> idx == -1 end)
      |> Stream.map(fn {height, idx} ->
        State.fetch!(state, Model.Block, {height, idx})
      end)
      |> Stream.map(fn Model.block(hash: hash) ->
        block = :aec_db.get_block(hash)

        hashrate =
          block
          |> :aec_blocks.difficulty()
          |> Node.difficulty_to_hashrate()

        time = :aec_blocks.time_in_msecs(block)

        time
        |> Stats.time_intervals()
        |> Enum.map(fn {interval, interval_start} ->
          {{:hashrate, interval, interval_start}, hashrate}
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

    {:ok, block_hashrates_added}
  end
end
