defmodule Integration.AeMdw.Db.Sync.StatsTest do
  use ExUnit.Case

  @moduletag :integration

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Db.StatsMutation

  require Model

  @initial_token_offer AeMdw.Node.token_supply_delta(0)
  @first_block_reward_height 181

  describe "new_mutation/2" do
    test "with all_cached? = false and 1 block reward" do
      %StatsMutation{stat: m_stat, sum_stat: m_sum_stat} =
        Stats.new_mutation(@first_block_reward_height - 1, false)

      assert Model.sum_stat(m_sum_stat, :block_reward) == 1
      assert Model.sum_stat(m_sum_stat, :dev_reward) == 0
      assert Model.sum_stat(m_sum_stat, :total_supply) == @initial_token_offer + 1

      assert Model.stat(m_stat, :inactive_names) > 0
      assert Model.stat(m_stat, :active_names) > 0
      assert Model.stat(m_stat, :active_auctions) > 0
      assert Model.stat(m_stat, :inactive_oracles) > 0
      assert Model.stat(m_stat, :active_oracles) > 0
      assert Model.stat(m_stat, :contracts) > 0
    end
  end
end
