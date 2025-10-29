defmodule AeMdw.Migrations.AddRomaAccountBalancesToTotalSupply do
  alias AeMdw.Db.HardforkPresets
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      Model.TotalStat
      |> RocksDbCF.stream()
      |> Enum.map(fn Model.total_stat(index: height, total_supply: old_total_supply) ->
          new_total_supply = old_total_supply + HardforkPresets.mint_sum(:roma)
          WriteMutation.new(
            Model.TotalStat,
            Model.total_stat(index: height, total_supply: new_total_supply)
          )
      end)

    _state = State.commit_db(state, mutations)
    {:ok, length(mutations)}
  end
end
