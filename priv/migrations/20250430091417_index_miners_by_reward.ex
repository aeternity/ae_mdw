defmodule AeMdw.Migrations.IndexMinersByReward do
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    Model.Miner
    |> RocksDbCF.stream()
    |> Stream.map(fn Model.miner(index: miner_pk, total_reward: total_reward) ->
      WriteMutation.new(
        Model.RewardMiner,
        Model.reward_miner(index: {total_reward, miner_pk})
      )
    end)
    |> Stream.chunk_every(1000)
    |> Stream.map(fn mutations ->
      _state = State.commit_db(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
    |> then(fn count ->
      {:ok, count}
    end)
  end
end
