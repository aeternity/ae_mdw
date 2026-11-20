defmodule AeMdw.Db.TotalStatisticsMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Collection
  alias AeMdw.Db.TotalStatisticsMutation
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.StatisticsMutation
  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Node

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

  describe "merge/1" do
    test "returns the mutations as they are when none of them updates total statistics" do
      mutations = [StatisticsMutation.new([{{{:blocks, :micro}, :day, 1}, 1}]), nil]

      assert mutations == TotalStatisticsMutation.merge(mutations)
    end

    test "writes the same counts as the micro block mutations of a generation crossing midnight" do
      # over 32 statistics in the merged mutation, so that a map no longer keeps them sorted
      type_counts = Node.tx_types() |> Enum.take(17) |> Map.new(&{&1, 1})
      midnight = 20_000 * 86_400_000
      previous_day_index = {{:total_transactions, :all}, :day, 19_998}
      day_index = {{:total_transactions, :all}, :day, 19_999}
      next_day_index = {{:total_transactions, :all}, :day, 20_000}

      mutations =
        -2..2
        |> Enum.map(&Stats.micro_block_mutations(midnight + &1 * 3_000, type_counts))
        |> List.flatten()

      merged_mutations =
        mutations
        |> StatisticsMutation.merge()
        |> TotalStatisticsMutation.merge()

      # a MemStore is mutable, so each run gets its own
      execute = fn mutations ->
        state =
          NullStore.new()
          |> MemStore.new()
          |> State.new()
          |> State.put(Model.Statistic, Model.statistic(index: previous_day_index, count: 100))

        Enum.reduce(mutations, state, &Mutation.execute/2)
      end

      merged_state = execute.(merged_mutations)

      assert {:ok, Model.statistic(count: 134)} =
               State.get(merged_state, Model.Statistic, day_index)

      assert {:ok, Model.statistic(count: 185)} =
               State.get(merged_state, Model.Statistic, next_day_index)

      assert statistics(merged_state) == statistics(execute.(mutations))
    end
  end

  defp statistics(state) do
    state
    |> Collection.stream(Model.Statistic, :forward, nil, nil)
    |> Enum.map(&State.fetch!(state, Model.Statistic, &1))
  end
end
