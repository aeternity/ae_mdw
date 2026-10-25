defmodule AeMdw.Migrations.IndexMinersByRewardTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  setup_all do
    migration = AeMdw.Migrations.IndexMinersByReward

    # migrations are only compiled when applied, at startup unless they already were
    unless Code.ensure_loaded?(migration) do
      Code.require_file("priv/migrations/20260424120000_index_miners_by_reward.ex")
    end

    {:ok, migration: migration}
  end

  setup do
    global_state = :persistent_term.get(:global_state, nil)
    pks = Enum.map(1..3, fn _i -> :crypto.strong_rand_bytes(32) end)

    on_exit(fn ->
      :persistent_term.put(:global_state, global_state)

      Enum.each(pks, &Database.dirty_delete(Model.Miner, &1))
      Enum.each(reward_keys(pks), &Database.dirty_delete(Model.RewardMiner, &1))
    end)

    {:ok, pks: pks}
  end

  test "it indexes the miners by their total reward, also when run again", %{
    migration: migration,
    pks: pks
  } do
    rewards = Enum.zip(pks, [30, 10, 20])

    Enum.each(rewards, fn {pk, reward} ->
      Database.dirty_write(Model.Miner, Model.miner(index: pk, total_reward: reward))
    end)

    expected = rewards |> Enum.map(fn {pk, reward} -> {reward, pk} end) |> Enum.sort()
    miners_count = Database.count(Model.Miner)

    for _run <- 1..2 do
      assert {:ok, ^miners_count} = migration.run(State.new(), false)
      assert ^expected = reward_keys(pks)
    end
  end

  defp reward_keys(pks) do
    Model.RewardMiner
    |> Database.all_keys()
    |> Enum.filter(fn {_reward, pk} -> pk in pks end)
    |> Enum.sort()
  end
end
