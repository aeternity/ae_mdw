defmodule AeMdw.Db.Sync.StatsTest do
  use ExUnit.Case

  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Db.StatisticsMutation

  describe "statistics_mutations/2" do
    test "when no count, it returns nil" do
      time = 1_691_422_166_000
      refute Stats.txs_statistics_mutations(time, %{})
    end

    test "when count > 0, it returnsa mutation with all stats changes" do
      time1 = 0
      time2 = 31_536_000_000

      type_counts = %{
        spend_tx: 1,
        oracle_register_tx: 18
      }

      mutation1 =
        StatisticsMutation.new([
          {{{:transactions, :all}, :day, 0}, 19},
          {{{:transactions, :oracle_register_tx}, :day, 0}, 18},
          {{{:transactions, :spend_tx}, :day, 0}, 1},
          {{{:transactions, :all}, :week, 0}, 19},
          {{{:transactions, :oracle_register_tx}, :week, 0}, 18},
          {{{:transactions, :spend_tx}, :week, 0}, 1},
          {{{:transactions, :all}, :month, 1}, 19},
          {{{:transactions, :oracle_register_tx}, :month, 1}, 18},
          {{{:transactions, :spend_tx}, :month, 1}, 1}
        ])

      mutation2 =
        StatisticsMutation.new([
          {{{:transactions, :all}, :day, 365}, 19},
          {{{:transactions, :oracle_register_tx}, :day, 365}, 18},
          {{{:transactions, :spend_tx}, :day, 365}, 1},
          {{{:transactions, :all}, :week, 52}, 19},
          {{{:transactions, :oracle_register_tx}, :week, 52}, 18},
          {{{:transactions, :spend_tx}, :week, 52}, 1},
          {{{:transactions, :all}, :month, 13}, 19},
          {{{:transactions, :oracle_register_tx}, :month, 13}, 18},
          {{{:transactions, :spend_tx}, :month, 13}, 1}
        ])

      assert ^mutation1 = Stats.txs_statistics_mutations(time1, type_counts)
      assert ^mutation2 = Stats.txs_statistics_mutations(time2, type_counts)
    end
  end
end
