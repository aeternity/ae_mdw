defmodule AeMdw.Db.Sync.StatsTest do
  use ExUnit.Case

  alias AeMdw.Db.Sync.Stats
  alias AeMdw.Db.StatisticsMutation

  describe "micro_block_mutations/2" do
    test "when no count, it returns block counts only" do
      mutation =
        StatisticsMutation.new([
          {{{:blocks, :micro}, :day, 0}, 1},
          {{{:blocks, :all}, :day, 0}, 1},
          {{{:blocks, :micro}, :week, 0}, 1},
          {{{:blocks, :all}, :week, 0}, 1},
          {{{:blocks, :micro}, :month, 0}, 1},
          {{{:blocks, :all}, :month, 0}, 1}
        ])

      time = 2
      assert ^mutation = Stats.micro_block_mutations(time, %{})
    end

    test "when count > 0, it returns a mutation with all stats changes" do
      time1 = 0
      time2 = 31_536_000_000

      type_counts = [
        oracle_register_tx: 18,
        spend_tx: 1
      ]

      mutation1 =
        StatisticsMutation.new([
          {{{:blocks, :micro}, :day, 0}, 1},
          {{{:blocks, :all}, :day, 0}, 1},
          {{{:blocks, :micro}, :week, 0}, 1},
          {{{:blocks, :all}, :week, 0}, 1},
          {{{:blocks, :micro}, :month, 0}, 1},
          {{{:blocks, :all}, :month, 0}, 1},
          {{{:transactions, :all}, :day, 0}, 19},
          {{{:transactions, :oracle_register_tx}, :day, 0}, 18},
          {{{:transactions, :spend_tx}, :day, 0}, 1},
          {{{:transactions, :all}, :week, 0}, 19},
          {{{:transactions, :oracle_register_tx}, :week, 0}, 18},
          {{{:transactions, :spend_tx}, :week, 0}, 1},
          {{{:transactions, :all}, :month, 0}, 19},
          {{{:transactions, :oracle_register_tx}, :month, 0}, 18},
          {{{:transactions, :spend_tx}, :month, 0}, 1}
        ])

      mutation2 =
        StatisticsMutation.new([
          {{{:blocks, :micro}, :day, 365}, 1},
          {{{:blocks, :all}, :day, 365}, 1},
          {{{:blocks, :micro}, :week, 52}, 1},
          {{{:blocks, :all}, :week, 52}, 1},
          {{{:blocks, :micro}, :month, 12}, 1},
          {{{:blocks, :all}, :month, 12}, 1},
          {{{:transactions, :all}, :day, 365}, 19},
          {{{:transactions, :oracle_register_tx}, :day, 365}, 18},
          {{{:transactions, :spend_tx}, :day, 365}, 1},
          {{{:transactions, :all}, :week, 52}, 19},
          {{{:transactions, :oracle_register_tx}, :week, 52}, 18},
          {{{:transactions, :spend_tx}, :week, 52}, 1},
          {{{:transactions, :all}, :month, 12}, 19},
          {{{:transactions, :oracle_register_tx}, :month, 12}, 18},
          {{{:transactions, :spend_tx}, :month, 12}, 1}
        ])

      assert ^mutation1 = Stats.micro_block_mutations(time1, type_counts)
      assert ^mutation2 = Stats.micro_block_mutations(time2, type_counts)
    end
  end

  describe "key_block_mutations/2" do
    test "it returns a mutation with all the statistics changes" do
      time1 = 0
      time2 = 31_536_000_000

      [key_block1, key_block2] =
        Enum.map([time1, time2], fn time ->
          :aec_blocks.new_key(
            1,
            <<0::256>>,
            <<1::256>>,
            <<2::256>>,
            2,
            3,
            time,
            :default,
            1,
            <<3::256>>,
            <<4::256>>
          )
        end)

      mutation1 =
        StatisticsMutation.new([
          {{{:blocks, :key}, :day, 0}, 1},
          {{{:blocks, :all}, :day, 0}, 1},
          {{{:blocks, :key}, :week, 0}, 1},
          {{{:blocks, :all}, :week, 0}, 1},
          {{{:blocks, :key}, :month, 0}, 1},
          {{{:blocks, :all}, :month, 0}, 1}
        ])

      mutation2 =
        StatisticsMutation.new([
          {{{:blocks, :key}, :day, 365}, 1},
          {{{:blocks, :all}, :day, 365}, 1},
          {{{:blocks, :key}, :week, 52}, 1},
          {{{:blocks, :all}, :week, 52}, 1},
          {{{:blocks, :key}, :month, 12}, 1},
          {{{:blocks, :all}, :month, 12}, 1}
        ])

      assert mutation1 in Stats.key_block_mutations(1, key_block1, [], 1, 2, false)
      assert mutation2 in Stats.key_block_mutations(1, key_block2, [], 1, 2, false)
    end
  end
end
