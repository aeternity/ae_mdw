defmodule AeMdw.Db.CumulativeStatisticsMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.CumulativeStatisticsMutation
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
      indexfn = fn interval_start -> {{:cumulative_transactions, :all}, :day, interval_start} end

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

      mutation = CumulativeStatisticsMutation.new(records)

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
  end
end
