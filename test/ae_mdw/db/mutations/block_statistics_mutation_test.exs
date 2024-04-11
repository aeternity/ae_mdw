defmodule AeMdw.Db.BlocksStatisticsMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.BlockStatisticsMutation

  require Model

  setup do
    global_state_ref = :persistent_term.get(:global_state, nil)
    on_exit(fn -> :persistent_term.put(:global_state, global_state_ref) end)
  end

  describe "execute/2" do
    test "it creates a statistic per day/week/month" do
      index1 = {:names_activated, :day, 8}
      index2 = {:names_activated, :week, 1}
      index3 = {:names_activated, :month, 0}
      time = 1_000 * 3_600 * 8 * 24

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.inc_stat(:micro_block_names_activated)
        |> State.inc_stat(:micro_block_names_activated)

      assert 2 = State.get_stat(state, :micro_block_names_activated, 0)

      mutation = BlockStatisticsMutation.new(time)

      new_state = State.commit_mem(state, [mutation])

      assert {:ok, Model.statistic(count: 2)} = State.get(new_state, Model.Statistic, index1)
      assert {:ok, Model.statistic(count: 2)} = State.get(new_state, Model.Statistic, index2)
      assert {:ok, Model.statistic(count: 2)} = State.get(new_state, Model.Statistic, index3)
    end
  end
end
