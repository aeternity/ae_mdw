defmodule AeMdw.MinerStats.FoldTest do
  use ExUnit.Case, async: true

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.MinerStats.Fold
  alias AeMdw.MinerStatsFixtures

  import AeMdw.TestUtil, only: [empty_state: 0, all_keys: 2]

  require Model

  @m1 <<1::256>>
  @m2 <<2::256>>
  @m3 <<3::256>>
  @b1 <<11::256>>
  @b2 <<12::256>>
  @b3 <<13::256>>
  @day :timer.hours(24)

  describe "fold/2" do
    setup do
      state =
        empty_state()
        |> Fold.fold(facts(20, @m1, @b1, txs: 3, fees: 30, micro_blocks: 2, time: 1_000))
        |> Fold.fold(
          facts(21, @m2, @b1,
            txs: 1,
            fees: 10,
            micro_blocks: 1,
            time: 2_000,
            rewards: %{@b1 => 50}
          )
        )
        |> Fold.fold(
          facts(22, @m1, @b2,
            difficulty: 200,
            time: 3_000,
            rewards: %{@b2 => 70, @b1 => 5}
          )
        )

      {:ok, state: state}
    end

    test "it tracks the first and last activity and the totals of each miner", %{state: state} do
      assert {:ok,
              Model.miner_entity(
                first_height: 20,
                first_time: 1_000,
                last_height: 22,
                last_time: 3_000,
                blocks: 2,
                txs: 3,
                rewards: 0,
                fees: 30
              )} = State.get(state, Model.MinerEntity, {:miner, @m1})

      assert {:ok, Model.miner_entity(blocks: 1, txs: 1, fees: 10)} =
               State.get(state, Model.MinerEntity, {:miner, @m2})
    end

    test "it tracks the beneficiaries and the rewards they get", %{state: state} do
      assert {:ok,
              Model.miner_entity(
                first_height: 20,
                last_height: 21,
                blocks: 2,
                txs: 4,
                fees: 40,
                rewards: 55
              )} = State.get(state, Model.MinerEntity, {:beneficiary, @b1})

      assert {:ok, Model.miner_entity(first_height: 22, blocks: 1, rewards: 70)} =
               State.get(state, Model.MinerEntity, {:beneficiary, @b2})
    end

    test "it sorts the miners by each of their totals and activity", %{state: state} do
      assert [{1, @m2}, {2, @m1}] = sorted(state, :miner, :blocks)
      assert [{1, @m2}, {3, @m1}] = sorted(state, :miner, :txs)
      assert [{10, @m2}, {30, @m1}] = sorted(state, :miner, :fees)
      assert [{20, @m1}, {21, @m2}] = sorted(state, :miner, :first_active)
      assert [{21, @m2}, {22, @m1}] = sorted(state, :miner, :last_active)
      assert [] = sorted(state, :miner, :rewards)

      assert [{1, @b2}, {2, @b1}] = sorted(state, :beneficiary, :blocks)
      assert [{55, @b1}, {70, @b2}] = sorted(state, :beneficiary, :rewards)
    end

    test "it sorts a beneficiary that was only paid as never active", %{state: state} do
      b4 = <<14::256>>
      state = Fold.fold(state, facts(41, @m3, @b3, rewards: %{b4 => 9}))

      assert [{-1, ^b4} | _rest] = sorted(state, :beneficiary, :first_active)
      assert [{-1, ^b4} | _rest] = sorted(state, :beneficiary, :last_active)
      assert [{0, ^b4} | _rest] = sorted(state, :beneficiary, :blocks)
      assert {9, b4} in sorted(state, :beneficiary, :rewards)
    end

    test "it adds a row to the bucket of each miner with their totals up to there", %{
      state: state
    } do
      assert {:ok,
              Model.miner_bucket(
                blocks: 2,
                txs: 4,
                rewards: 55,
                fees: 40,
                blocks_total: 2,
                txs_total: 4,
                rewards_total: 55,
                fees_total: 40
              )} = State.get(state, Model.MinerBucket, {:beneficiary, @b1, :bucket, 1})

      assert {:ok, Model.miner_bucket(blocks: 2, rewards: 0, blocks_total: 2)} =
               State.get(state, Model.MinerBucket, {:miner, @m1, :bucket, 1})

      assert State.exists?(state, Model.BucketMiner, {:miner, :bucket, 1, @m1})
      assert State.exists?(state, Model.BucketMiner, {:miner, :bucket, 1, @m2})
      assert State.exists?(state, Model.BucketMiner, {:beneficiary, :bucket, 1, @b2})
    end

    test "it links the beneficiaries with the miner keys that mined for them", %{state: state} do
      assert {:ok, Model.beneficiary_link(blocks: 1, first_height: 20, last_height: 20)} =
               State.get(state, Model.BeneficiaryLink, {@b1, @m1})

      assert {:ok, Model.beneficiary_link(blocks: 1, first_height: 21, last_height: 21)} =
               State.get(state, Model.BeneficiaryLink, {@b1, @m2})

      assert {:ok, Model.beneficiary_link(blocks: 1, first_height: 22, last_height: 22)} =
               State.get(state, Model.BeneficiaryLink, {@b2, @m1})

      refute State.exists?(state, Model.BeneficiaryLink, {@b2, @m2})
    end

    test "it aggregates the generations of the bucket in the network row", %{state: state} do
      assert {:ok,
              Model.network_bucket(
                start_height: 20,
                end_height: 22,
                start_time: 1_000,
                end_time: 3_000,
                blocks: 3,
                micro_blocks: 3,
                txs: 4,
                rewards: 125,
                fees: 40,
                difficulty_sum: 400,
                active_miners: 2,
                active_beneficiaries: 2,
                new_miners: 2,
                new_beneficiaries: 2,
                blocks_total: 3,
                txs_total: 4,
                rewards_total: 125,
                fees_total: 40,
                miners_total: 2,
                beneficiaries_total: 2
              )} = State.get(state, Model.NetworkBucket, {:bucket, 1})
    end

    test "it carries the totals to the next bucket and only counts what's new", %{state: state} do
      state =
        state
        |> Fold.fold(facts(40, @m1, @b1, txs: 2, fees: 5, time: 4_000))
        |> Fold.fold(facts(41, @m3, @b3, time: 5_000, rewards: %{@b2 => 9}))

      assert {:ok,
              Model.network_bucket(
                start_height: 40,
                end_height: 41,
                blocks: 2,
                txs: 2,
                rewards: 9,
                active_miners: 2,
                active_beneficiaries: 2,
                new_miners: 1,
                new_beneficiaries: 1,
                blocks_total: 5,
                txs_total: 6,
                rewards_total: 134,
                fees_total: 45,
                miners_total: 3,
                beneficiaries_total: 3
              )} = State.get(state, Model.NetworkBucket, {:bucket, 2})

      assert {:ok, Model.miner_bucket(blocks: 1, txs: 2, blocks_total: 3, txs_total: 5)} =
               State.get(state, Model.MinerBucket, {:miner, @m1, :bucket, 2})
    end

    test "it adds the rewards of a beneficiary that didn't mine in the bucket", %{state: state} do
      state = Fold.fold(state, facts(41, @m3, @b3, rewards: %{@b2 => 9}))

      assert {:ok,
              Model.miner_bucket(
                blocks: 0,
                rewards: 9,
                blocks_total: 1,
                rewards_total: 79
              )} = State.get(state, Model.MinerBucket, {:beneficiary, @b2, :bucket, 2})

      assert {:ok, Model.miner_entity(last_height: 22, rewards: 79)} =
               State.get(state, Model.MinerEntity, {:beneficiary, @b2})

      assert {:ok, Model.network_bucket(active_beneficiaries: 1)} =
               State.get(state, Model.NetworkBucket, {:bucket, 2})

      refute State.exists?(state, Model.BucketMiner, {:beneficiary, :bucket, 2, @b2})
      assert State.exists?(state, Model.BucketMiner, {:beneficiary, :bucket, 2, @b3})
    end
  end

  describe "fold/2 intervals" do
    setup do
      {:ok, state: MinerStatsFixtures.fold_history(empty_state())}
    end

    test "it groups the generations by the day of their time", %{state: state} do
      assert {:ok,
              Model.network_bucket(
                start_height: 20,
                end_height: 22,
                blocks: 3,
                active_miners: 2,
                new_miners: 2,
                blocks_total: 3,
                miners_total: 2
              )} = State.get(state, Model.NetworkBucket, {:day, 0})

      assert {:ok,
              Model.network_bucket(
                start_height: 40,
                end_height: 60,
                start_time: 86_404_000,
                end_time: 86_406_000,
                blocks: 3,
                txs: 2,
                rewards: 9,
                active_miners: 2,
                new_miners: 1,
                blocks_total: 6,
                miners_total: 3
              )} = State.get(state, Model.NetworkBucket, {:day, 1})

      assert {:ok, Model.miner_bucket(blocks: 2, txs: 3, blocks_total: 2)} =
               State.get(state, Model.MinerBucket, {:miner, @m1, :day, 0})

      assert {:ok, Model.miner_bucket(blocks: 2, txs: 2, blocks_total: 4)} =
               State.get(state, Model.MinerBucket, {:miner, @m1, :day, 1})

      assert State.exists?(state, Model.BucketMiner, {:miner, :day, 0, @m2})
      refute State.exists?(state, Model.BucketMiner, {:miner, :day, 1, @m2})
    end

    test "it keeps the same stats for the weeks and months, counting the miners once", %{
      state: state
    } do
      for interval <- [:week, :month] do
        assert {:ok,
                Model.network_bucket(
                  start_height: 20,
                  end_height: 60,
                  start_time: 1_000,
                  end_time: 86_406_000,
                  blocks: 6,
                  micro_blocks: 3,
                  txs: 6,
                  rewards: 134,
                  fees: 45,
                  active_miners: 3,
                  active_beneficiaries: 3,
                  new_miners: 3,
                  new_beneficiaries: 3,
                  blocks_total: 6,
                  rewards_total: 134,
                  miners_total: 3
                )} = State.get(state, Model.NetworkBucket, {interval, 0})

        assert {:ok, Model.miner_bucket(blocks: 4, txs: 5, fees: 35, blocks_total: 4)} =
                 State.get(state, Model.MinerBucket, {:miner, @m1, interval, 0})

        assert {:ok, Model.miner_bucket(blocks: 1, rewards: 79, rewards_total: 79)} =
                 State.get(state, Model.MinerBucket, {:beneficiary, @b2, interval, 0})

        assert State.exists?(state, Model.BucketMiner, {:miner, interval, 0, @m3})
        refute State.exists?(state, Model.BucketMiner, {:miner, interval, 0, @b1})
      end
    end

    test "it starts a new group of an interval from the totals of the last one, even after a gap" do
      state = fold_times(empty_state(), [1_000, @day + 2_000, 3 * @day + 3_000, 40 * @day])

      assert {:ok,
              Model.network_bucket(index: {:day, 1}, blocks: 1, blocks_total: 2, txs_total: 2)} =
               State.get(state, Model.NetworkBucket, {:day, 1})

      assert :not_found = State.get(state, Model.NetworkBucket, {:day, 2})

      assert {:ok, Model.network_bucket(index: {:day, 3}, blocks: 1, blocks_total: 3)} =
               State.get(state, Model.NetworkBucket, {:day, 3})

      assert {:ok, Model.network_bucket(index: {:week, 0}, blocks: 3, blocks_total: 3)} =
               State.get(state, Model.NetworkBucket, {:week, 0})

      assert {:ok, Model.network_bucket(index: {:week, 5}, blocks: 1, blocks_total: 4)} =
               State.get(state, Model.NetworkBucket, {:week, 5})

      assert {:ok, Model.network_bucket(index: {:month, 0}, blocks: 3, blocks_total: 3)} =
               State.get(state, Model.NetworkBucket, {:month, 0})

      assert {:ok, Model.network_bucket(index: {:month, 1}, blocks: 1, blocks_total: 4)} =
               State.get(state, Model.NetworkBucket, {:month, 1})
    end

    test "it never goes back to the group of an earlier generation" do
      state = fold_times(empty_state(), [@day + 1_000, 1_000])

      assert {:ok, Model.network_bucket(blocks: 2, blocks_total: 2)} =
               State.get(state, Model.NetworkBucket, {:day, 1})

      assert :not_found = State.get(state, Model.NetworkBucket, {:day, 0})
    end
  end

  describe "bucket/1" do
    test "it groups generations by the bucket size" do
      size = Fold.bucket_size()

      assert 0 == Fold.bucket(size - 1)
      assert 1 == Fold.bucket(size)
      assert 1 == Fold.bucket(2 * size - 1)
    end
  end

  defp fold_times(state, times) do
    times
    |> Enum.with_index(100)
    |> Enum.reduce(state, fn {time, height}, state ->
      Fold.fold(state, facts(height, @m1, @b1, txs: 1, fees: 2, time: time))
    end)
  end

  defp sorted(state, role, order_by) do
    for {^role, ^order_by, value, pk} <- all_keys(state, Model.MinerOrder), do: {value, pk}
  end

  defp facts(height, miner, beneficiary, opts) do
    %{
      height: height,
      time: Keyword.get(opts, :time, height * 1_000),
      miner: miner,
      beneficiary: beneficiary,
      difficulty: Keyword.get(opts, :difficulty, 100),
      micro_blocks: Keyword.get(opts, :micro_blocks, 0),
      txs: Keyword.get(opts, :txs, 0),
      fees: Keyword.get(opts, :fees, 0),
      rewards: Keyword.get(opts, :rewards, %{})
    }
  end
end
