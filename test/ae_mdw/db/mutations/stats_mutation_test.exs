defmodule AeMdw.Db.StatsMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.StatsMutation

  import Mock

  require Model

  @initial_token_offer AeMdw.Node.token_supply_delta(0)
  @first_block_reward 1_000_000_000_000_000_000

  describe "new_mutation/2 with all_cached? = false" do
    test "on 1st block reward" do
      height = 300

      on_exit(fn ->
        AeMdw.Ets.clear(:stat_sync_cache)
        Database.dirty_delete(Model.DeltaStat, height)
        Database.dirty_delete(Model.TotalStat, height)
      end)

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

      State.commit(State.new(), [mutation])

      {:ok, m_delta_stat} = Database.fetch(Model.DeltaStat, height)
      {:ok, m_total_stat} = Database.fetch(Model.TotalStat, height)

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

      on_exit(fn ->
        AeMdw.Ets.clear(:stat_sync_cache)
        Database.dirty_delete(Model.DeltaStat, height)
        Database.dirty_delete(Model.TotalStat, height)
      end)

      prev_delta_stat = Model.delta_stat(index: height, block_reward: @first_block_reward)

      prev_total_stat =
        Model.total_stat(
          index: height,
          block_reward: @first_block_reward,
          total_supply: @initial_token_offer + @first_block_reward
        )

      Database.dirty_write(Model.DeltaStat, prev_delta_stat)
      Database.dirty_write(Model.TotalStat, prev_total_stat)

      state =
        State.new()
        |> State.inc_stat(:block_reward, @first_block_reward)

      mutation = StatsMutation.new(height, true)

      State.commit(state, [mutation])

      {:ok, m_delta_stat} = Database.fetch(Model.DeltaStat, height)
      {:ok, m_total_stat} = Database.fetch(Model.TotalStat, height)

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
      on_exit(fn ->
        AeMdw.Ets.clear(:stat_sync_cache)
      end)

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

      state =
        State.new()
        |> State.inc_stat(:block_reward, increased_block_reward)
        |> State.inc_stat(:dev_reward, increased_dev_reward)
        |> State.inc_stat(:names_activated, 1)

      mutation = StatsMutation.new(height, true)

      State.commit(state, [mutation])

      {:ok, m_delta_stat} = Database.fetch(Model.DeltaStat, height)
      {:ok, m_total_stat} = Database.fetch(Model.TotalStat, height + 1)

      total_block_reward = @first_block_reward + increased_block_reward
      total_dev_reward = increased_dev_reward

      assert ^total_block_reward = Model.total_stat(m_total_stat, :block_reward)
      assert ^total_dev_reward = Model.total_stat(m_total_stat, :dev_reward)

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
           get: fn
             Model.TotalStat, ^height -> {:ok, Model.total_stat(active_auctions: 1)}
             Model.InactiveName, _plain_name -> {:ok, Model.name()}
           end,
           count: fn
             Model.ActiveName -> 3
             Model.ActiveOracle -> 4
             Model.AuctionExpiration -> 5
           end,
           next_key: fn _tab, _init_key -> :none end
         ]},
        {State, [:passthrough], put: fn state, _tab, _record -> state end},
        {Collection, [],
         [
           stream: fn
             _state, Model.InactiveNameExpiration, _dir, _scope, _cursor ->
               [{1, "a.chain"}, {2, "b.chain"}]

             _state, Model.InactiveOracleExpiration, _dir, _scope, _cursor ->
               []
           end,
           stream: fn
             _state, Model.Origin, _start_key -> [1, 2, 3]
             _state, Model.IntTransferTx, _start_key -> []
           end
         ]}
      ] do
        state = State.new()
        assert StatsMutation.execute(mutation, state)

        assert_called(State.put(state, Model.DeltaStat, expected_delta))
        assert_called(State.put(state, Model.TotalStat, expected_total))
      end
    end

    test "with all_cached? = true, on 1st block reward, it stores stats using ets cache" do
      height = 30

      state =
        State.new()
        |> State.inc_stat(:block_reward, 5)

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
           get: fn Model.TotalStat, ^height ->
             {:ok, Model.total_stat(active_auctions: 1)}
           end
         ]},
        {State, [:passthrough], put: fn state, _tab, _record -> state end}
      ] do
        assert StatsMutation.execute(mutation, state)

        assert_called(State.put(state, Model.DeltaStat, expected_delta))
        assert_called(State.put(state, Model.TotalStat, expected_total))
      end
    end
  end
end
