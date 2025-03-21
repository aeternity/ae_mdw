defmodule AeMdw.Migrations.AddHoldersCount do
  @moduledoc false
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Stats
  alias AeMdw.Util

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    kb = {{1, Util.min_bin()}, {Util.max_int(), Util.max_256bit_bin()}}

    holders_count =
      Model.BalanceAccount
      |> RocksDbCF.stream(key_boundary: kb)
      |> Stream.filter(fn Model.balance_account(index: {balance, _account}) -> balance > 0 end)
      |> Enum.count()

    mutation =
      WriteMutation.new(
        Model.Stat,
        Model.stat(index: Stats.holders_count_key(), payload: holders_count)
      )

    _state =
      State.commit_db(state, [mutation])

    {:ok, holders_count}
  end
end
