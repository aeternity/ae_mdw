defmodule AeMdw.Db.TotalStatisticsMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.TotalStatisticsMutation
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State

  require Model

  setup do
    global_state_ref = :persistent_term.get(:global_state, nil)
    on_exit(fn -> :persistent_term.put(:global_state, global_state_ref) end)
  end

  describe "execute/2" do
    test "it creates and updates a statistic per day" do
      indexfn = fn interval_start -> {{:total_transactions, :all}, :day, interval_start} end

      records = [
        {indexfn.(1), 1},
        {indexfn.(2), 5},
        {indexfn.(3), 5},
        {indexfn.(4), 6},
        {indexfn.(5), 6},
        {indexfn.(6), 7}
      ]

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()

      mutation = TotalStatisticsMutation.new(records)

      new_state = State.commit_mem(state, [mutation])

      assert {:ok, Model.statistic(count: 1)} = State.get(new_state, Model.Statistic, indexfn.(1))

      assert {:ok, Model.statistic(count: 6 = day2_count)} =
               State.get(new_state, Model.Statistic, indexfn.(2))

      assert {:ok, Model.statistic(count: 11)} =
               State.get(new_state, Model.Statistic, indexfn.(3))

      assert {:ok, Model.statistic(count: 17 = day4_count)} =
               State.get(new_state, Model.Statistic, indexfn.(4))

      assert {:ok, Model.statistic(count: 23)} =
               State.get(new_state, Model.Statistic, indexfn.(5))

      assert {:ok, Model.statistic(count: 30)} =
               State.get(new_state, Model.Statistic, indexfn.(6))

      assert day4_count - day2_count == 11
    end

    test "it increments an existing statistic without adding the previous one again" do
      indexfn = fn interval_start -> {{:total_transactions, :all}, :day, interval_start} end

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()

      mutation1 = TotalStatisticsMutation.new([{indexfn.(1), 1}, {indexfn.(2), 5}])
      mutation2 = TotalStatisticsMutation.new([{indexfn.(2), 3}])

      new_state = State.commit_mem(state, [mutation1, mutation2])

      assert {:ok, Model.statistic(count: 1)} = State.get(new_state, Model.Statistic, indexfn.(1))
      assert {:ok, Model.statistic(count: 9)} = State.get(new_state, Model.Statistic, indexfn.(2))
    end

    test "it doesn't carry over counts from other tx types or intervals" do
      all_day_index = {{:total_transactions, :all}, :day, 1}
      all_week_index = {{:total_transactions, :all}, :week, 0}
      spend_day_index = {{:total_transactions, :spend_tx}, :day, 2}

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()

      mutation =
        TotalStatisticsMutation.new([
          {all_day_index, 4},
          {all_week_index, 3},
          {spend_day_index, 2}
        ])

      new_state = State.commit_mem(state, [mutation])

      assert {:ok, Model.statistic(count: 4)} =
               State.get(new_state, Model.Statistic, all_day_index)

      assert {:ok, Model.statistic(count: 3)} =
               State.get(new_state, Model.Statistic, all_week_index)

      assert {:ok, Model.statistic(count: 2)} =
               State.get(new_state, Model.Statistic, spend_day_index)
    end
  end
end
