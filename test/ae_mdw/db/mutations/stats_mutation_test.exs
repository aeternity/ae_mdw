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

  describe "new_mutation/2 with all_cached? = false" do
    test "on 1st block reward" do
      height = 300

      prev_delta_stat = Model.delta_stat(index: height - 1)

      prev_total_stat =
        Model.total_stat(
          index: height,
          block_reward: 0,
          total_supply: @initial_token_offer
        )

      dev_reward = 1_001
      block_reward = 1_002

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.DeltaStat, prev_delta_stat)
        |> State.put(Model.TotalStat, prev_total_stat)
        |> State.put(
          Model.IntTransferTx,
          Model.int_transfer_tx(
            index: {{height, -1}, "reward_dev", <<0::256>>, -1},
            amount: dev_reward
          )
        )
        |> State.put(
          Model.IntTransferTx,
          Model.int_transfer_tx(
            index: {{height, -1}, "reward_block", <<0::256>>, -1},
            amount: block_reward
          )
        )

      state = StatsMutation.execute(StatsMutation.new(height, "", 0, 0, 0, false), state)

      {:ok, m_delta_stat} = State.get(state, Model.DeltaStat, height)
      {:ok, m_total_stat} = State.get(state, Model.TotalStat, height + 1)

      assert Model.delta_stat(m_delta_stat, :dev_reward) == dev_reward
      assert Model.delta_stat(m_delta_stat, :block_reward) == block_reward

      assert Model.total_stat(m_total_stat, :dev_reward) == dev_reward
      assert Model.total_stat(m_total_stat, :block_reward) == block_reward

      assert Model.total_stat(m_total_stat, :total_supply) ==
               @initial_token_offer + block_reward + dev_reward
    end
  end

  describe "new_mutation/2 with all_cached? = true" do
    test "on 1st block reward" do
      height = 300

      prev_delta_stat = Model.delta_stat(index: height - 1, block_reward: 0)

      prev_total_stat =
        Model.total_stat(
          index: height,
          total_supply: @initial_token_offer
        )

      dev_reward = 1_001
      block_reward = 1_002

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.DeltaStat, prev_delta_stat)
        |> State.put(Model.TotalStat, prev_total_stat)
        |> State.inc_stat(:dev_reward, dev_reward)
        |> State.inc_stat(:block_reward, block_reward)

      state = StatsMutation.execute(StatsMutation.new(height, "", 0, 0, 0, true), state)

      {:ok, m_delta_stat} = State.get(state, Model.DeltaStat, height)
      {:ok, m_total_stat} = State.get(state, Model.TotalStat, height + 1)

      assert Model.delta_stat(m_delta_stat, :dev_reward) == dev_reward
      assert Model.delta_stat(m_delta_stat, :block_reward) == block_reward

      assert Model.total_stat(m_total_stat, :dev_reward) == dev_reward
      assert Model.total_stat(m_total_stat, :block_reward) == block_reward

      assert Model.total_stat(m_total_stat, :total_supply) ==
               @initial_token_offer + block_reward + dev_reward
    end
  end

  describe "execute/2" do
    test "with all_cached? = false, computes stat counting state keys" do
      height = 100
      mutation = StatsMutation.new(height, "", 0, 0, 0, false)

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(
          Model.TotalStat,
          Model.total_stat(
            index: height,
            active_auctions: 1,
            active_names: 1,
            inactive_names: 1,
            active_oracles: 1,
            inactive_oracles: 1,
            contracts: 1
          )
        )
        |> tap(fn store ->
          Enum.reduce(1..7, store, fn i, store ->
            Store.put(
              store,
              Model.InactiveOracle,
              Model.oracle(index: <<i::256>>)
            )
          end)
        end)
        |> Store.put(
          Model.InactiveOracleExpiration,
          Model.expiration(index: {height - 1, <<7::256>>})
        )
        |> tap(fn store ->
          Enum.reduce(2..7, store, fn i, store ->
            Store.put(
              store,
              Model.InactiveOracleExpiration,
              Model.expiration(index: {height, <<i::256>>})
            )
          end)
        end)
        |> tap(fn store ->
          Enum.reduce(1..6, store, fn _i, store ->
            Store.put(
              store,
              Model.ActiveOracle,
              Model.oracle(index: :crypto.strong_rand_bytes(32))
            )
          end)
        end)
        |> tap(fn store ->
          Enum.reduce(1..5, store, fn i, store ->
            Store.put(store, Model.ActiveName, Model.name(index: "name#{i}-active.chain"))
          end)
        end)
        |> tap(fn store ->
          Enum.reduce(1..5, store, fn i, store ->
            Store.put(
              store,
              Model.ActiveNameExpiration,
              Model.expiration(index: {height + 50, "name#{i}-active.chain"})
            )
          end)
        end)
        |> Store.put(
          Model.InactiveName,
          Model.name(index: "name1-prev-expired.chain", expire: {{height - 11, 0}, -1})
        )
        |> Store.put(
          Model.InactiveName,
          Model.name(index: "name2-expired.chain", expire: {{height, 0}, -1})
        )
        |> Store.put(
          Model.InactiveName,
          Model.name(index: "name3-expired.chain", expire: {{height, 0}, -1})
        )
        |> Store.put(
          Model.InactiveName,
          Model.name(index: "name4-revoked.chain", revoke: {{height, 0}, 1_001})
        )
        |> Store.put(
          Model.InactiveNameExpiration,
          Model.expiration(index: {height - 11, "name1-prev-expired.chain"})
        )
        |> Store.put(
          Model.InactiveNameExpiration,
          Model.expiration(index: {height, "name2-expired.chain"})
        )
        |> Store.put(
          Model.InactiveNameExpiration,
          Model.expiration(index: {height, "name3-expired.chain"})
        )
        |> Store.put(
          Model.InactiveNameExpiration,
          Model.expiration(index: {height, "name4-revoked.chain"})
        )
        |> Store.put(
          Model.AuctionExpiration,
          Model.expiration(index: {height - 10, "auction1.chain"})
        )
        |> Store.put(
          Model.AuctionExpiration,
          Model.expiration(index: {height + 100, "auction2.chain"})
        )
        |> Store.put(
          Model.AuctionExpiration,
          Model.expiration(index: {height + 100, "auction3.chain"})
        )
        |> Store.put(
          Model.Origin,
          Model.origin(index: {:contract_create_tx, :crypto.strong_rand_bytes(32), 1_002})
        )
        |> Store.put(
          Model.Origin,
          Model.origin(index: {:contract_create_tx, :crypto.strong_rand_bytes(32), 1_003})
        )
        |> State.new()

      expected_delta =
        Model.delta_stat(
          index: height,
          auctions_started: 2,
          names_activated: 5 - 1,
          names_expired: 2,
          names_revoked: 1,
          oracles_registered: 6 - 1,
          oracles_expired: 7 - 1,
          contracts_created: 1
        )

      expected_total =
        Model.total_stat(
          index: height + 1,
          active_auctions: 2 + 1,
          inactive_oracles: ObjectKeys.count_inactive_oracles(state),
          active_oracles: ObjectKeys.count_active_oracles(state),
          active_names: ObjectKeys.count_active_names(state),
          inactive_names: ObjectKeys.count_inactive_names(state),
          contracts: 2
        )

      state = StatsMutation.execute(mutation, state)

      assert ^expected_delta = State.fetch!(state, Model.DeltaStat, height)
      assert ^expected_total = State.fetch!(state, Model.TotalStat, height + 1)
    end

    test "with all_cached? = true, it increments oracles and names total stats based on keys" do
      height = 200

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
        |> State.inc_stat(:contracts_created)

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
          contracts_created: 1
        )

      expected_total =
        Model.total_stat(
          index: height + 1,
          contracts: 1,
          inactive_oracles: ObjectKeys.count_inactive_oracles(state),
          active_oracles: ObjectKeys.count_active_oracles(state),
          active_names: ObjectKeys.count_active_names(state),
          inactive_names: ObjectKeys.count_inactive_names(state)
        )

      state = StatsMutation.execute(mutation, state)

      assert expected_delta == State.fetch!(state, Model.DeltaStat, height)
      assert expected_total == State.fetch!(state, Model.TotalStat, height + 1)
    end
  end
end
