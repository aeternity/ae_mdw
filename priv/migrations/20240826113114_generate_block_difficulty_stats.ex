defmodule AeMdw.Migrations.GenerateBlockDifficultyStats do
  @moduledoc """
    Generate block difficulty statistics.
  """
  alias AeMdw.Collection
  alias AeMdw.Db.KeyBlockStatsMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {_state, block_difficulties_added} =
      state
      |> Collection.stream(Model.Block, :backward, nil, nil)
      |> Stream.filter(fn {_height, idx} -> idx == -1 end)
      |> Stream.map(fn {height, idx} ->
        State.fetch!(state, Model.Block, {height, idx})
      end)
      |> Stream.map(fn Model.block(hash: hash) ->
        block = :aec_db.get_block(hash)
        difficulty = :aec_blocks.difficulty(block)
        time = :aec_blocks.time_in_msecs(block)
        KeyBlockStatsMutation.new(time, difficulty)
      end)
      |> Stream.chunk_every(1000)
      |> Enum.reduce({state, 0}, fn mutations, {acc_state, count} ->
        {
          State.commit_db(acc_state, mutations),
          count + length(mutations)
        }
      end)

    {:ok, block_difficulties_added}
  end
end
