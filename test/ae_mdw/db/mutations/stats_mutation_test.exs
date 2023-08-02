defmodule AeMdw.Db.StatsMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.Store
  alias AeMdw.Db.State
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Db.Sync.ObjectKeys

  require Model

  @initial_token_offer AeMdw.Node.token_supply_delta(0)
  @first_block_reward 1_000_000_000_000_000_000

  setup_all do
    Enum.each(1..6, fn _i -> ObjectKeys.put_inactive_oracle(:crypto.strong_rand_bytes(32)) end)
    Enum.each(1..5, fn _i -> ObjectKeys.put_active_oracle(:crypto.strong_rand_bytes(32)) end)

    Enum.each(1..4, fn i -> ObjectKeys.put_active_name("names#{i}.chain") end)
    Enum.each(1..3, fn i -> ObjectKeys.put_inactive_name("names#{i}-inactive.chain") end)
  end

  describe "new_mutation/2 with all_cached? = false" do
    test "on 1st block reward" do
      height = 300

      prev_delta_stat = Model.delta_stat(index: height - 1, block_reward: 0)

      prev_total_stat =
        Model.total_stat(
          index: height,
          block_reward: 0,
          total_supply: @initial_token_offer
        )

      int_transfer_reward =
        Model.int_transfer_tx(
          index: {{height, -1}, "reward_block", <<0::256>>, -1},
          amount: @first_block_reward
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.DeltaStat, prev_delta_stat)
        |> State.put(Model.TotalStat, prev_total_stat)
        |> State.put(Model.IntTransferTx, int_transfer_reward)

      state = StatsMutation.execute(StatsMutation.new(height, "", 0, 0, 0, false), state)

      {:ok, m_delta_stat} = State.get(state, Model.DeltaStat, height)
      {:ok, m_total_stat} = State.get(state, Model.TotalStat, height + 1)

      assert Model.delta_stat(m_delta_stat, :dev_reward) == 0
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

      assert Model.total_stat(m_total_stat, :dev_reward) == 0
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

      prev_delta_stat = Model.delta_stat(index: height - 1, block_reward: 0)

      prev_total_stat =
        Model.total_stat(
          index: height,
          block_reward: 0,
          total_supply: @initial_token_offer
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.DeltaStat, prev_delta_stat)
        |> State.put(Model.TotalStat, prev_total_stat)
        |> State.inc_stat(:block_reward, @first_block_reward)

      state = StatsMutation.execute(StatsMutation.new(height, "", 0, 0, 0, true), state)

      {:ok, m_delta_stat} = State.get(state, Model.DeltaStat, height)
      {:ok, m_total_stat} = State.get(state, Model.TotalStat, height + 1)

      assert Model.total_stat(m_total_stat, :block_reward) == @first_block_reward
      assert Model.total_stat(m_total_stat, :dev_reward) == 0

      assert Model.total_stat(m_total_stat, :total_supply) ==
               @initial_token_offer + @first_block_reward

      assert Model.delta_stat(m_delta_stat, :block_reward) == @first_block_reward
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
          names_activated: 4,
          names_expired: 2,
          names_revoked: 0,
          oracles_registered: 5,
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
          active_names: 4,
          inactive_names: 3,
          active_oracles: 5,
          inactive_oracles: 6,
          contracts: 0
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(Model.TotalStat, Model.total_stat(index: height, active_auctions: 1))
        |> tap(fn store ->
          Enum.reduce(1..6, store, fn _i, store ->
            Store.put(
              store,
              Model.InactiveOracle,
              Model.oracle(index: :crypto.strong_rand_bytes(32))
            )
          end)
        end)
        |> tap(fn store ->
          Enum.reduce(1..5, store, fn _i, store ->
            Store.put(
              store,
              Model.ActiveOracle,
              Model.oracle(index: :crypto.strong_rand_bytes(32))
            )
          end)
        end)
        |> tap(fn store ->
          Enum.reduce(1..4, store, fn i, store ->
            Store.put(store, Model.ActiveName, Model.name(index: "name#{i}.chain"))
          end)
        end)
        |> tap(fn store ->
          Enum.reduce(1..3, store, fn i, store ->
            Store.put(store, Model.InactiveName, Model.name(index: "name#{i}-inactive.chain"))
          end)
        end)
        |> Store.put(
          Model.InactiveNameExpiration,
          Model.expiration(index: {height, "name1-inactive.chain"})
        )
        |> Store.put(
          Model.InactiveNameExpiration,
          Model.expiration(index: {height, "name2-inactive.chain"})
        )
        |> Store.put(Model.AuctionExpiration, Model.expiration(index: {22, "name1.chain"}))
        |> Store.put(Model.AuctionExpiration, Model.expiration(index: {22, "name2.chain"}))
        |> Store.put(Model.AuctionExpiration, Model.expiration(index: {22, "name3.chain"}))
        |> Store.put(Model.AuctionExpiration, Model.expiration(index: {22, "name4.chain"}))
        |> Store.put(Model.AuctionExpiration, Model.expiration(index: {22, "name5.chain"}))
        |> State.new()

      state = StatsMutation.execute(mutation, state)
      assert ^expected_delta = State.fetch!(state, Model.DeltaStat, height)
      assert ^expected_total = State.fetch!(state, Model.TotalStat, height + 1)
    end

    test "with all_cached? = true, it increments oracles and names total stats based on keys" do
      height = 1000

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.DeltaStat, Model.delta_stat(index: height - 1))
        |> State.put(Model.TotalStat, Model.total_stat(index: height))
        |> State.inc_stat(:oracles_expired, 6)
        |> State.inc_stat(:oracles_registered, 5)
        |> State.inc_stat(:names_activated, 4)
        |> State.inc_stat(:names_expired, 2)
        |> State.inc_stat(:names_revoked)

      mutation = StatsMutation.new(height, "", 0, 0, 0, true)

      expected_delta =
        Model.delta_stat(
          index: height,
          auctions_started: 0,
          names_activated: 4,
          names_expired: 2,
          names_revoked: 1,
          oracles_registered: 5,
          oracles_expired: 6,
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
          active_names: 4,
          inactive_names: 3,
          active_oracles: 5,
          inactive_oracles: 6,
          contracts: 0
        )

      state = StatsMutation.execute(mutation, state)

      assert expected_delta == State.fetch!(state, Model.DeltaStat, height)
      assert expected_total == State.fetch!(state, Model.TotalStat, height + 1)
    end
  end
end
