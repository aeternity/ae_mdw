defmodule Integration.AeMdw.Db.Sync.StatsTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Db.IntTransfer

  require Model

  @initial_token_offer AeMdw.Node.token_supply_delta(0)

  @first_block_reward_height 181
  @first_block_reward 1_000_000_000_000_000_000

  # block_height from /txs/forward?type=
  @first_name_height 194
  @first_oracle_height 4165
  @first_contract_height 4187

  describe "new_mutation/2" do
    test "with all_cached? = false and 1st block reward" do
      %StatsMutation{delta_stat: m_delta_stat, total_stat: m_total_stat} =
        Stats.new_mutation(@first_block_reward_height, false)

      assert Model.delta_stat(m_delta_stat, :block_reward) == @first_block_reward
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

      Model.DeltaStat
      |> Database.dirty_all_keys()
      |> Enum.map(&Database.fetch!(Model.DeltaStat, &1))
      |> Enum.each(fn m_delta_stat ->
        assert Model.delta_stat(m_delta_stat, :dev_reward) >= 0
        assert Model.delta_stat(m_delta_stat, :auctions_started) >= 0
        assert Model.delta_stat(m_delta_stat, :names_activated) >= 0
        assert Model.delta_stat(m_delta_stat, :names_expired) >= 0
        assert Model.delta_stat(m_delta_stat, :names_revoked) >= 0
        assert Model.delta_stat(m_delta_stat, :oracles_registered) >= 0
        assert Model.delta_stat(m_delta_stat, :oracles_expired) >= 0
        assert Model.delta_stat(m_delta_stat, :contracts_created) >= 0
      end)
    end
  end

  test "with all_cached? = true and 1st block reward" do
    on_exit(fn ->
      AeMdw.Ets.clear(:stat_sync_cache)
    end)

    AeMdw.Ets.inc(:stat_sync_cache, :block_reward, @first_block_reward)

    %StatsMutation{delta_stat: m_delta_stat, total_stat: m_total_stat} =
      Stats.new_mutation(@first_block_reward_height, true)

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

  test "with all_cached? = true and 1st name" do
    on_exit(fn ->
      AeMdw.Ets.clear(:stat_sync_cache)
    end)

    AeMdw.Ets.inc(:stat_sync_cache, :names_activated)
    %StatsMutation{delta_stat: m_delta_stat} = Stats.new_mutation(@first_name_height, true)
    # delta/transitions are only reflected at height + 1
    AeMdw.Ets.clear(:stat_sync_cache)

    %StatsMutation{total_stat: m_total_stat} =
      Stats.new_mutation(@first_name_height + 1, true)

    total_block_reward =
      1..@first_name_height |> Enum.map(&IntTransfer.read_block_reward/1) |> Enum.sum()

    total_dev_reward =
      1..@first_name_height |> Enum.map(&IntTransfer.read_dev_reward/1) |> Enum.sum()

    assert Model.total_stat(m_total_stat, :block_reward) == total_block_reward
    assert Model.total_stat(m_total_stat, :dev_reward) == total_dev_reward

    total_supply =
      0..(@first_name_height + 1) |> Enum.map(&AeMdw.Node.token_supply_delta/1) |> Enum.sum()

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

  test "with all_cached? = true and 1st oracle" do
    on_exit(fn ->
      AeMdw.Ets.clear(:stat_sync_cache)
    end)

    AeMdw.Ets.inc(:stat_sync_cache, :oracles_registered)
    %StatsMutation{delta_stat: m_delta_stat} = Stats.new_mutation(@first_oracle_height, true)
    # delta/transitions are only reflected at height + 1
    AeMdw.Ets.clear(:stat_sync_cache)

    %StatsMutation{total_stat: m_total_stat} =
      Stats.new_mutation(@first_oracle_height + 1, true)

    total_block_reward =
      1..@first_oracle_height |> Enum.map(&IntTransfer.read_block_reward/1) |> Enum.sum()

    total_dev_reward =
      1..@first_oracle_height |> Enum.map(&IntTransfer.read_dev_reward/1) |> Enum.sum()

    assert Model.total_stat(m_total_stat, :block_reward) == total_block_reward
    assert Model.total_stat(m_total_stat, :dev_reward) == total_dev_reward

    total_supply =
      0..(@first_oracle_height + 1) |> Enum.map(&AeMdw.Node.token_supply_delta/1) |> Enum.sum()

    assert Model.total_stat(m_total_stat, :total_supply) ==
             total_supply + total_block_reward + total_dev_reward

    assert Model.total_stat(m_total_stat, :inactive_names) == 0
    assert Model.total_stat(m_total_stat, :active_names) == 3
    assert Model.total_stat(m_total_stat, :active_auctions) == 0
    assert Model.total_stat(m_total_stat, :inactive_oracles) == 0
    assert Model.total_stat(m_total_stat, :active_oracles) == 1
    assert Model.total_stat(m_total_stat, :contracts) == 0

    assert Model.delta_stat(m_delta_stat, :auctions_started) == 0
    assert Model.delta_stat(m_delta_stat, :names_activated) == 0
    assert Model.delta_stat(m_delta_stat, :names_expired) == 0
    assert Model.delta_stat(m_delta_stat, :names_revoked) == 0
    assert Model.delta_stat(m_delta_stat, :oracles_registered) == 1
    assert Model.delta_stat(m_delta_stat, :oracles_expired) == 0
    assert Model.delta_stat(m_delta_stat, :contracts_created) == 0
  end

  test "with all_cached? = true and 1st contract" do
    on_exit(fn ->
      AeMdw.Ets.clear(:stat_sync_cache)
    end)

    AeMdw.Ets.inc(:stat_sync_cache, :contracts_created)
    %StatsMutation{delta_stat: m_delta_stat} = Stats.new_mutation(@first_contract_height, true)
    # delta/transitions are only reflected at height + 1
    AeMdw.Ets.clear(:stat_sync_cache)

    %StatsMutation{total_stat: m_total_stat} =
      Stats.new_mutation(@first_contract_height + 1, true)

    total_block_reward =
      1..@first_contract_height |> Enum.map(&IntTransfer.read_block_reward/1) |> Enum.sum()

    total_dev_reward =
      1..@first_contract_height |> Enum.map(&IntTransfer.read_dev_reward/1) |> Enum.sum()

    assert Model.total_stat(m_total_stat, :block_reward) == total_block_reward
    assert Model.total_stat(m_total_stat, :dev_reward) == total_dev_reward

    total_supply =
      0..(@first_contract_height + 1) |> Enum.map(&AeMdw.Node.token_supply_delta/1) |> Enum.sum()

    assert Model.total_stat(m_total_stat, :total_supply) ==
             total_supply + total_block_reward + total_dev_reward

    assert Model.total_stat(m_total_stat, :inactive_names) == 0
    assert Model.total_stat(m_total_stat, :active_names) == 3
    assert Model.total_stat(m_total_stat, :active_auctions) == 0
    assert Model.total_stat(m_total_stat, :inactive_oracles) == 0
    assert Model.total_stat(m_total_stat, :active_oracles) == 1
    assert Model.total_stat(m_total_stat, :contracts) == 1

    assert Model.delta_stat(m_delta_stat, :auctions_started) == 0
    assert Model.delta_stat(m_delta_stat, :names_activated) == 0
    assert Model.delta_stat(m_delta_stat, :names_expired) == 0
    assert Model.delta_stat(m_delta_stat, :names_revoked) == 0
    assert Model.delta_stat(m_delta_stat, :oracles_registered) == 0
    assert Model.delta_stat(m_delta_stat, :oracles_expired) == 0
    assert Model.delta_stat(m_delta_stat, :contracts_created) == 1
  end
end
