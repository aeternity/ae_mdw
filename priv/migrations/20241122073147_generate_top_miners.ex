defmodule AeMdw.Migrations.GenerateTopMiners do
  @moduledoc """
  Generate top miners for blocks that have already passed
  """
  alias AeMdw.Db.TopMinerStatsMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    count =
      Model.Block
      |> RocksDbCF.stream()
      |> Stream.filter(fn Model.block(index: {_key_index, micro_index}) -> micro_index == -1 end)
      |> Stream.map(fn Model.block(hash: hash) ->
        {:ok, key_block} = :aec_chain.get_block(hash)
        time = :aec_blocks.time_in_msecs(key_block)

        miner =
          key_block
          |> :aec_blocks.to_header()
          |> :aec_headers.beneficiary()

        TopMinerStatsMutation.new([miner], time)
      end)
      |> Stream.chunk_every(1000)
      |> Stream.map(fn mutations ->
        _state = State.commit_db(state, mutations)

        length(mutations)
      end)
      |> Enum.sum()

    {:ok, count}
  end
end
