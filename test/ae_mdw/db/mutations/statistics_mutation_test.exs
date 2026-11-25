defmodule AeMdw.Db.StatisticsMutationTest do
  use ExUnit.Case, async: true

  alias AeMdw.Db.Model
  alias AeMdw.Db.StatisticsMutation
  alias AeMdw.Db.WriteMutation

  require Model

  describe "merge/1" do
    test "returns the mutations as they are when none of them updates statistics" do
      mutations = [WriteMutation.new(Model.Block, Model.block(index: {1, 0})), nil]

      assert mutations == StatisticsMutation.merge(mutations)
    end

    test "adds up the increments of each statistic in one mutation after the other mutations" do
      write_mutation1 = WriteMutation.new(Model.Block, Model.block(index: {1, 0}))
      write_mutation2 = WriteMutation.new(Model.Block, Model.block(index: {1, 1}))
      micro_day = {{:blocks, :micro}, :day, 10}
      micro_week = {{:blocks, :micro}, :week, 1}
      key_day = {{:blocks, :key}, :day, 10}

      mutations = [
        StatisticsMutation.new([{micro_day, 1}, {micro_week, 1}]),
        write_mutation1,
        StatisticsMutation.new([{micro_day, 1}, {micro_week, 1}]),
        write_mutation2,
        StatisticsMutation.new([{key_day, 1}])
      ]

      assert [
               write_mutation1,
               write_mutation2,
               StatisticsMutation.new([{key_day, 1}, {micro_day, 2}, {micro_week, 2}])
             ] == StatisticsMutation.merge(mutations)
    end
  end
end
