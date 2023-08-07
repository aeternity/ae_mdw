defmodule AeMdw.Db.Sync.StatsTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Db.StatisticsMutation

  describe "statistics_mutations/2" do
    test "when no count, it returns nil" do
      time = 1_691_422_166_000
      refute Stats.statistics_mutations(time, %{})
    end

    test "when count > 0, it returnsa mutation with all stats changes" do
      time = 1_691_422_166_000

      type_counts = %{
        spend_tx: 1,
        oracle_register_tx: 18
      }

      mutation =
        StatisticsMutation.new([
          {{{:transactions, :all}, :day, 19576}, 19},
          {{{:transactions, :oracle_register_tx}, :day, 19576}, 18},
          {{{:transactions, :spend_tx}, :day, 19576}, 1},
          {{{:transactions, :all}, :week, 2796}, 19},
          {{{:transactions, :oracle_register_tx}, :week, 2796}, 18},
          {{{:transactions, :spend_tx}, :week, 2796}, 1},
          {{{:transactions, :all}, :month, 644}, 19},
          {{{:transactions, :oracle_register_tx}, :month, 644}, 18},
          {{{:transactions, :spend_tx}, :month, 644}, 1}
        ])

      assert ^mutation = Stats.statistics_mutations(time, type_counts)
    end
  end
end
