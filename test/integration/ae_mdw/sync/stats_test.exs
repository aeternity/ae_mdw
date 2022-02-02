defmodule Integration.AeMdw.Db.Sync.StatsTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Db.StatsMutation
  alias AeMdw.Db.IntTransfer

  require Model

  @initial_token_offer AeMdw.Node.token_supply_delta(0)
  @first_block_reward_height 181
  @first_block_reward 1_000_000_000_000_000_000
  @first_contract_height 4187

  describe "new_mutation/2" do
    test "with all_cached? = false and 1st block reward" do
      %StatsMutation{stat: m_stat, total_stat: m_total_stat} =
        Stats.new_mutation(@first_block_reward_height, false)

      assert Model.total_stat(m_total_stat, :block_reward) == @first_block_reward

      assert Model.total_stat(m_total_stat, :total_supply) ==
               @initial_token_offer + @first_block_reward

      assert Model.stat(m_stat, :block_reward) == @first_block_reward

      # > 0 because it gets the sum of objects for the last height when all_cached? = false
      if AeMdw.Db.Sync.BlockIndex.max_kbi() > 500_000 do
        assert Model.total_stat(m_total_stat, :dev_reward) > 0
        assert Model.total_stat(m_total_stat, :inactive_names) > 0
        assert Model.total_stat(m_total_stat, :active_names) > 0
        assert Model.total_stat(m_total_stat, :active_auctions) > 0
        assert Model.total_stat(m_total_stat, :inactive_oracles) > 0
        assert Model.total_stat(m_total_stat, :active_oracles) > 0
        assert Model.total_stat(m_total_stat, :contracts) > 0

        assert Model.stat(m_stat, :dev_reward) > 0
        assert Model.stat(m_stat, :inactive_names) > 0
        assert Model.stat(m_stat, :active_names) > 0
        assert Model.stat(m_stat, :active_auctions) > 0
        assert Model.stat(m_stat, :inactive_oracles) > 0
        assert Model.stat(m_stat, :active_oracles) > 0
        assert Model.stat(m_stat, :contracts) > 0
      end
    end
  end

  test "with all_cached? = true and 1st block reward" do
    AeMdw.Ets.inc(:stat_sync_cache, :block_reward, @first_block_reward)

    on_exit(fn ->
      AeMdw.Ets.clear(:stat_sync_cache)
    end)

    %StatsMutation{stat: m_stat, total_stat: m_total_stat} =
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

    assert Model.stat(m_stat, :block_reward) == @first_block_reward
    assert Model.stat(m_stat, :dev_reward) == 0
    assert Model.stat(m_stat, :inactive_names) == 0
    assert Model.stat(m_stat, :active_names) == 0
    assert Model.stat(m_stat, :active_auctions) == 0
    assert Model.stat(m_stat, :inactive_oracles) == 0
    assert Model.stat(m_stat, :active_oracles) == 0
    assert Model.stat(m_stat, :contracts) == 0
  end

  test "with all_cached? = true and 1st contract" do
    AeMdw.Ets.inc(:stat_sync_cache, :contracts)

    on_exit(fn ->
      AeMdw.Ets.clear(:stat_sync_cache)
    end)

    %StatsMutation{stat: m_stat, total_stat: m_total_stat} =
      Stats.new_mutation(@first_contract_height, true)

    total_block_reward =
      1..(@first_contract_height - 1) |> Enum.map(&IntTransfer.read_block_reward/1) |> Enum.sum()

    total_dev_reward =
      1..(@first_contract_height - 1) |> Enum.map(&IntTransfer.read_dev_reward/1) |> Enum.sum()

    assert Model.total_stat(m_total_stat, :block_reward) == total_block_reward
    assert Model.total_stat(m_total_stat, :dev_reward) == total_dev_reward

    total_supply =
      0..@first_contract_height |> Enum.map(&AeMdw.Node.token_supply_delta/1) |> Enum.sum()

    assert Model.total_stat(m_total_stat, :total_supply) ==
             total_supply + total_block_reward + total_dev_reward

    assert Model.total_stat(m_total_stat, :inactive_names) == 0
    assert Model.total_stat(m_total_stat, :active_names) == 3
    assert Model.total_stat(m_total_stat, :active_auctions) == 0
    assert Model.total_stat(m_total_stat, :inactive_oracles) == 0
    assert Model.total_stat(m_total_stat, :active_oracles) == 1
    assert Model.total_stat(m_total_stat, :contracts) == 1

    assert Model.stat(m_stat, :block_reward) == 0
    assert Model.stat(m_stat, :dev_reward) == 0
    assert Model.stat(m_stat, :inactive_names) == 0
    assert Model.stat(m_stat, :active_names) == 0
    assert Model.stat(m_stat, :active_auctions) == 0
    assert Model.stat(m_stat, :inactive_oracles) == 0
    assert Model.stat(m_stat, :active_oracles) == 0
    assert Model.stat(m_stat, :contracts) == 1
  end
end
