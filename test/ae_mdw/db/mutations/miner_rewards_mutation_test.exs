defmodule AeMdw.Db.MinerRewardsMutationTest do
  use ExUnit.Case, async: true

  alias AeMdw.Db.MinerRewardsMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Stats

  import AeMdw.TestUtil, only: [empty_state: 0]

  require Model

  @miner1 <<1::256>>
  @miner2 <<2::256>>

  describe "execute/2" do
    test "it indexes a new miner by its reward" do
      state = execute(empty_state(), %{@miner1 => 10})

      assert {:ok, Model.miner(total_reward: 10)} = State.get(state, Model.Miner, @miner1)
      assert State.exists?(state, Model.RewardMiner, {10, @miner1})
    end

    test "it moves an existing miner to its new total reward" do
      state =
        empty_state()
        |> execute(%{@miner1 => 10})
        |> execute(%{@miner1 => 5})

      assert {:ok, Model.miner(total_reward: 15)} = State.get(state, Model.Miner, @miner1)
      assert State.exists?(state, Model.RewardMiner, {15, @miner1})
      refute State.exists?(state, Model.RewardMiner, {10, @miner1})
    end

    test "it counts each miner once" do
      state =
        empty_state()
        |> execute(%{@miner1 => 10, @miner2 => 20})
        |> execute(%{@miner1 => 1, @miner2 => 2})

      assert {:ok, Model.stat(payload: 2)} =
               State.get(state, Model.Stat, Stats.miners_count_key())
    end
  end

  defp execute(state, rewards),
    do: rewards |> MinerRewardsMutation.new() |> MinerRewardsMutation.execute(state)
end
