defmodule AeMdw.Db.StatsMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.StatsMutation

  import Mock

  require Model

  describe "execute/2" do
    test "with all_cached? = false, on 1st block reward it stores the stat using database counts" do
      AeMdw.Ets.clear(:stat_sync_cache)

      height = 21
      mutation = StatsMutation.new(height, false)
      txn = :txn

      expected_delta =
        Model.delta_stat(
          index: height,
          auctions_started: 4,
          names_activated: 3,
          names_expired: 2,
          names_revoked: 0,
          oracles_registered: 4,
          oracles_expired: 0,
          contracts_created: 0,
          block_reward: 0,
          dev_reward: 0
        )

      expected_total =
        Model.total_stat(
          index: height + 1,
          block_reward: 0,
          dev_reward: 0,
          total_supply: 0,
          active_auctions: 5,
          active_names: 1,
          inactive_names: 2,
          active_oracles: 4,
          inactive_oracles: 0,
          contracts: 0
        )

      with_mocks [
        {Database, [],
         [
           fetch!: fn
             Model.TotalStat, ^height -> Model.total_stat(active_auctions: 1)
             Model.InactiveName, _plain_name -> Model.name()
           end,
           count_keys: fn
             Model.ActiveName -> 3
             Model.ActiveOracle -> 4
             Model.AuctionExpiration -> 5
           end,
           write: fn ^txn, _tab, _record -> :ok end,
           next_key: fn _tab, _init_key -> :none end
         ]},
        {Collection, [],
         [
           stream: fn
             Model.InactiveNameExpiration, _dir, _scope, _cursor ->
               [{1, "a.chain"}, {2, "b.chain"}]

             Model.InactiveOracleExpiration, _dir, _scope, _cursor ->
               []
           end,
           stream: fn
             Model.Origin, _start_key -> [1, 2, 3]
             Model.IntTransferTx, _start_key -> []
           end
         ]}
      ] do
        assert StatsMutation.execute(mutation, txn)

        assert_called(Database.write(txn, Model.DeltaStat, expected_delta))
        assert_called(Database.write(txn, Model.TotalStat, expected_total))
      end
    end

    test "with all_cached? = true, on 1st block reward, it stores stats using ets cache" do
      AeMdw.Ets.clear(:stat_sync_cache)
      AeMdw.Ets.inc(:stat_sync_cache, :block_reward, 5)

      height = 30
      txn = :txn
      mutation = StatsMutation.new(height, true)

      expected_delta =
        Model.delta_stat(
          index: height,
          auctions_started: 0,
          names_activated: 0,
          names_expired: 0,
          names_revoked: 0,
          oracles_registered: 0,
          oracles_expired: 0,
          contracts_created: 0,
          block_reward: 5,
          dev_reward: 0
        )

      expected_total =
        Model.total_stat(
          index: height + 1,
          block_reward: 5,
          dev_reward: 0,
          total_supply: 5,
          active_auctions: 1,
          active_names: 0,
          inactive_names: 0,
          active_oracles: 0,
          inactive_oracles: 0,
          contracts: 0
        )

      with_mocks [
        {Database, [],
         [
           fetch!: fn Model.TotalStat, ^height -> Model.total_stat(active_auctions: 1) end,
           write: fn ^txn, _tab, _record -> :ok end
         ]}
      ] do
        assert StatsMutation.execute(mutation, txn)

        assert_called(Database.write(txn, Model.DeltaStat, expected_delta))
        assert_called(Database.write(txn, Model.TotalStat, expected_total))
      end
    end
  end
end
