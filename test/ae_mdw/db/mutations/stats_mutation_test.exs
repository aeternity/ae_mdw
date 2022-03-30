defmodule AeMdw.Db.StatsMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDb

  alias AeMdw.Db.StatsMutation

  import Mock

  require Model

  @initial_token_offer AeMdw.Node.token_supply_delta(0)
  @first_block_reward 1_000_000_000_000_000_000

  describe "new_mutation/2 with all_cached? = false" do
    test "on 1st block reward" do
      height = 300
      prev_delta_stat = Model.delta_stat(index: height, block_reward: @first_block_reward)

      prev_total_stat =
        Model.total_stat(
          index: height,
          block_reward: @first_block_reward,
          total_supply: @initial_token_offer + @first_block_reward
        )

      Database.dirty_write(Model.DeltaStat, prev_delta_stat)
      Database.dirty_write(Model.TotalStat, prev_total_stat)

      mutation = StatsMutation.new(height, false)
      {:ok, txn} = RocksDb.transaction_new()

      StatsMutation.execute(mutation, txn)

      {:ok, m_delta_stat} = Database.dirty_fetch(txn, Model.DeltaStat, height)
      {:ok, m_total_stat} = Database.dirty_fetch(txn, Model.TotalStat, height)

      assert Model.delta_stat(m_delta_stat, :dev_reward) >= 0
      assert Model.delta_stat(m_delta_stat, :auctions_started) >= 0
      assert Model.delta_stat(m_delta_stat, :names_activated) >= 0
      assert Model.delta_stat(m_delta_stat, :names_expired) >= 0
      assert Model.delta_stat(m_delta_stat, :names_revoked) >= 0
      assert Model.delta_stat(m_delta_stat, :oracles_registered) >= 0
      assert Model.delta_stat(m_delta_stat, :oracles_expired) >= 0
      assert Model.delta_stat(m_delta_stat, :contracts_created) >= 0

      assert Model.total_stat(m_total_stat, :block_reward) == @first_block_reward

      assert Model.total_stat(m_total_stat, :total_supply) ==
               @initial_token_offer + @first_block_reward

      assert Model.total_stat(m_total_stat, :dev_reward) >= 0
      assert Model.total_stat(m_total_stat, :active_names) >= 0
      assert Model.total_stat(m_total_stat, :inactive_names) >= 0
      assert Model.total_stat(m_total_stat, :active_auctions) >= 0
      assert Model.total_stat(m_total_stat, :inactive_oracles) >= 0
      assert Model.total_stat(m_total_stat, :active_oracles) >= 0
      assert Model.total_stat(m_total_stat, :contracts) >= 0
    end
  end

  describe "new_mutation/2 with all_cached? = true" do
    test "on 1st block reward" do
      height = 300
      prev_delta_stat = Model.delta_stat(index: height, block_reward: @first_block_reward)

      prev_total_stat =
        Model.total_stat(
          index: height,
          block_reward: @first_block_reward,
          total_supply: @initial_token_offer + @first_block_reward
        )

      Database.dirty_write(Model.DeltaStat, prev_delta_stat)
      Database.dirty_write(Model.TotalStat, prev_total_stat)

      AeMdw.Ets.inc(:stat_sync_cache, :block_reward, @first_block_reward)

      mutation = StatsMutation.new(height, true)
      {:ok, txn} = RocksDb.transaction_new()

      StatsMutation.execute(mutation, txn)

      {:ok, m_delta_stat} = Database.dirty_fetch(txn, Model.DeltaStat, height)
      {:ok, m_total_stat} = Database.dirty_fetch(txn, Model.TotalStat, height)

      assert Model.total_stat(m_total_stat, :block_reward) == @first_block_reward
      assert Model.total_stat(m_total_stat, :dev_reward) == 0

      assert Model.total_stat(m_total_stat, :total_supply) ==
               @initial_token_offer + @first_block_reward

      assert Model.total_stat(m_total_stat, :inactive_names) == 0
      assert Model.total_stat(m_total_stat, :active_names) == 0
      assert Model.total_stat(m_total_stat, :active_auctions) == 0
      assert Model.total_stat(m_total_stat, :inactive_oracles) == 0
      assert Model.total_stat(m_total_stat, :active_oracles) == 0
      assert Model.total_stat(m_total_stat, :contracts) == 0

      assert Model.delta_stat(m_delta_stat, :block_reward) == @first_block_reward
      assert Model.delta_stat(m_delta_stat, :auctions_started) == 0
      assert Model.delta_stat(m_delta_stat, :names_activated) == 0
      assert Model.delta_stat(m_delta_stat, :names_expired) == 0
      assert Model.delta_stat(m_delta_stat, :names_revoked) == 0
      assert Model.delta_stat(m_delta_stat, :oracles_registered) == 0
      assert Model.delta_stat(m_delta_stat, :oracles_expired) == 0
      assert Model.delta_stat(m_delta_stat, :contracts_created) == 0
    end

    test "when there's names activated on the cache, it grabs it to store the stats" do
      height = 300
      dev_amount = 50
      block_amount = 120
      increased_block_reward = 340
      increased_dev_reward = 340
      prev_delta_stat = Model.delta_stat(index: height, block_reward: 33)

      prev_total_stat =
        Model.total_stat(
          index: height,
          block_reward: @first_block_reward,
          total_supply: @initial_token_offer + @first_block_reward
        )

      int_transfer_tx =
        Model.int_transfer_tx(index: {{height, -1}, "reward_dev", <<>>, <<>>}, amount: dev_amount)

      int_transfer_tx2 =
        Model.int_transfer_tx(
          index: {{height, -1}, "reward_block", <<>>, <<>>},
          amount: block_amount
        )

      Database.dirty_write(Model.IntTransferTx, int_transfer_tx)
      Database.dirty_write(Model.IntTransferTx, int_transfer_tx2)
      Database.dirty_write(Model.DeltaStat, prev_delta_stat)
      Database.dirty_write(Model.TotalStat, prev_total_stat)

      # delta/transitions are only reflected at height + 1
      AeMdw.Ets.clear(:stat_sync_cache)

      AeMdw.Ets.set(:stat_sync_cache, :block_reward, increased_block_reward)
      AeMdw.Ets.set(:stat_sync_cache, :dev_reward, increased_dev_reward)
      AeMdw.Ets.inc(:stat_sync_cache, :names_activated)

      mutation = StatsMutation.new(height, true)
      {:ok, txn} = RocksDb.transaction_new()
      StatsMutation.execute(mutation, txn)

      {:ok, m_delta_stat} = Database.dirty_fetch(txn, Model.DeltaStat, height)
      {:ok, m_total_stat} = Database.dirty_fetch(txn, Model.TotalStat, height + 1)

      total_block_reward = @first_block_reward + increased_block_reward
      total_dev_reward = increased_dev_reward

      assert ^total_block_reward = Model.total_stat(m_total_stat, :block_reward)
      assert ^total_dev_reward = Model.total_stat(m_total_stat, :dev_reward)

      total_supply =
        0..height
        |> Enum.map(&AeMdw.Node.token_supply_delta/1)
        |> Enum.sum()

      assert Model.total_stat(m_total_stat, :total_supply) ==
               total_supply + total_block_reward + total_dev_reward

      assert Model.total_stat(m_total_stat, :inactive_names) == 0
      assert Model.total_stat(m_total_stat, :active_names) == 1
      assert Model.total_stat(m_total_stat, :active_auctions) == 0
      assert Model.total_stat(m_total_stat, :inactive_oracles) == 0
      assert Model.total_stat(m_total_stat, :active_oracles) == 0
      assert Model.total_stat(m_total_stat, :contracts) == 0

      assert Model.delta_stat(m_delta_stat, :auctions_started) == 0
      assert Model.delta_stat(m_delta_stat, :names_activated) == 1
      assert Model.delta_stat(m_delta_stat, :names_expired) == 0
      assert Model.delta_stat(m_delta_stat, :names_revoked) == 0
      assert Model.delta_stat(m_delta_stat, :oracles_registered) == 0
      assert Model.delta_stat(m_delta_stat, :oracles_expired) == 0
      assert Model.delta_stat(m_delta_stat, :contracts_created) == 0
    end
  end

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
