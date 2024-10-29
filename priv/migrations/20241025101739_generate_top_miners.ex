defmodule AeMdw.Migrations.GenerateTopMiners do
  alias AeMdw.Db.TopMinerStatsMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    # dev_benefs =
    #   for {protocol, _height} <- :aec_hard_forks.protocols(),
    #       {pk, _share} <- :aec_dev_reward.beneficiaries(protocol) do
    #     pk
    #   end

    # delay = :aec_governance.beneficiary_reward_delay()

    {_state, count} =
      Model.Block
      |> RocksDbCF.stream()
      |> Stream.filter(fn Model.block(index: {_key_index, micro_index}) -> micro_index == -1 end)
      |> Stream.map(fn Model.block() = block ->
        Model.block(hash: hash) = block
        {:ok, key_block} = :aec_chain.get_block(hash)
        time = :aec_blocks.time_in_msecs(key_block)

        miner =
          key_block
          |> :aec_blocks.to_header()
          |> :aec_headers.miner()

        TopMinerStatsMutation.new([{miner, 0}], time)
      end)
      |> Stream.chunk_every(1000)
      |> Enum.reduce({state, 0}, fn mutations, {state, count} ->
        len = length(mutations)
        {State.commit_db(state, mutations), count + len}
      end)

    {:ok, count}
  end
end
