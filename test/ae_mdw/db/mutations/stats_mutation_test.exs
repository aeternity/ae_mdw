defmodule AeMdw.Db.StatsMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Store
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

      mutation = StatsMutation.new(height, "", 0, 0, 0, false)

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

      mutation = StatsMutation.new(height, "", 0, 0, 0, true)

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

      mutation = StatsMutation.new(height, "", 0, 0, 0, true)

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
      height = 21
      mutation = StatsMutation.new(height, "", 0, 0, 0, false)

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

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(Model.TotalStat, Model.total_stat(index: height, active_auctions: 1))
        |> Store.put(Model.InactiveName, Model.name())
        |> Store.put(Model.ActiveName, Model.name(index: "name1.chain"))
        |> Store.put(Model.ActiveName, Model.name(index: "name2.chain"))
        |> Store.put(Model.ActiveName, Model.name(index: "name3.chain"))
        |> Store.put(
          Model.InactiveNameExpiration,
          Model.expiration(index: {height, "name1-inactive.chain"})
        )
        |> Store.put(
          Model.InactiveNameExpiration,
          Model.expiration(index: {height, "name2-inactive.chain"})
        )
        |> Store.put(Model.InactiveName, Model.name(index: "name1-inactive.chain"))
        |> Store.put(Model.InactiveName, Model.name(index: "name2-inactive.chain"))
        |> Store.put(Model.AuctionExpiration, Model.expiration(index: {22, "name1.chain"}))
        |> Store.put(Model.AuctionExpiration, Model.expiration(index: {22, "name2.chain"}))
        |> Store.put(Model.AuctionExpiration, Model.expiration(index: {22, "name3.chain"}))
        |> Store.put(Model.AuctionExpiration, Model.expiration(index: {22, "name4.chain"}))
        |> Store.put(Model.AuctionExpiration, Model.expiration(index: {22, "name5.chain"}))
        |> Store.put(Model.ActiveOracle, Model.oracle(index: "oracle-pk1"))
        |> Store.put(Model.ActiveOracle, Model.oracle(index: "oracle-pk2"))
        |> Store.put(Model.ActiveOracle, Model.oracle(index: "oracle-pk3"))
        |> Store.put(Model.ActiveOracle, Model.oracle(index: "oracle-pk4"))
        |> State.new()

      state = StatsMutation.execute(mutation, state)
      assert ^expected_delta = State.fetch!(state, Model.DeltaStat, height)
      assert ^expected_total = State.fetch!(state, Model.TotalStat, height + 1)
    end

    test "with all_cached? = true, on 1st block reward, it stores stats using ets cache" do
      height = 30

      state =
        State.new()
        |> State.inc_stat(:block_reward, 5)

      mutation = StatsMutation.new(height, "", 0, 0, 0, true)

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
           get: fn
             Model.TotalStat, ^height ->
               {:ok, Model.total_stat(active_auctions: 1)}

             Model.Stat, _key ->
               :not_found
           end,
           dirty_write: fn _txs, _record -> :ok end
         ]},
        {State, [:passthrough], put: fn state, _tab, _record -> state end}
      ] do
        assert StatsMutation.execute(mutation, state)

        assert_called(State.put(state, Model.DeltaStat, expected_delta))
        assert_called(State.put(state, Model.TotalStat, expected_total))
      end
    end

    test "with all_cached? = true, it increments inactive oracles only when it was a new one" do
      height = 1000

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.inc_stat(:oracles_expired, 3)
        |> State.inc_stat(:old_oracles_registered, 1)

      mutation = StatsMutation.new(height, "", 0, 0, 0, true)

      expected_delta =
        Model.delta_stat(
          index: height,
          auctions_started: 0,
          names_activated: 0,
          names_expired: 0,
          names_revoked: 0,
          oracles_registered: 0,
          oracles_expired: 3,
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
          active_auctions: 0,
          active_names: 0,
          inactive_names: 0,
          active_oracles: 0,
          inactive_oracles: 2,
          contracts: 0
        )

      state = State.put(state, Model.TotalStat, Model.total_stat(index: height))

      with_mocks [
        {State, [:passthrough],
         [
           get: fn
             _state, Model.TotalStat, ^height -> {:ok, Model.total_stat()}
             _state, Model.Stat, _key -> :not_found
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
