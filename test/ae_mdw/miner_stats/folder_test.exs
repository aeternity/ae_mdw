defmodule AeMdw.MinerStats.FolderTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.MinerStats.Facts
  alias AeMdw.MinerStats.Folder

  import Mock

  require Model

  @tables [
    Model.MinerEntity,
    Model.MinerBucket,
    Model.BucketMiner,
    Model.BeneficiaryLink,
    Model.NetworkBucket,
    Model.DeltaStat,
    Model.Stat
  ]

  setup do
    Enum.each(1..45, &Database.dirty_write(Model.DeltaStat, Model.delta_stat(index: &1)))

    on_exit(fn ->
      Enum.each(@tables, fn table ->
        table |> Database.all_keys() |> Enum.each(&Database.dirty_delete(table, &1))
      end)
    end)
  end

  describe "fold_chunk/2" do
    test "it folds each complete bucket only once, in chunks" do
      with_mock Facts, fetch: fn _state, height -> {:ok, facts(height)} end do
        assert 0 == Folder.folded_height(State.new())

        assert :more = Folder.fold_chunk(State.new(), 25)
        assert 25 == Folder.folded_height(State.new())
        assert_called_exactly(Facts.fetch(:_, :_), 25)

        assert {:caught_up, 14} = Folder.fold_chunk(State.new(), 25)
        assert 39 == Folder.folded_height(State.new())

        assert {:caught_up, 14} = Folder.fold_chunk(State.new(), 25)
        assert_called_exactly(Facts.fetch(:_, :_), 39)
      end

      assert {:ok, Model.miner_entity(blocks: 39, first_height: 1, last_height: 39)} =
               State.get(State.new(), Model.MinerEntity, {:miner, <<1::256>>})

      assert {:ok, Model.network_bucket(blocks: 20, blocks_total: 39)} =
               State.get(State.new(), Model.NetworkBucket, {1, 1})
    end

    test "it waits for the first bucket to complete" do
      Enum.each(11..45, &Database.dirty_delete(Model.DeltaStat, &1))

      with_mock Facts, fetch: fn _state, height -> {:ok, facts(height)} end do
        assert {:caught_up, 9} = Folder.fold_chunk(State.new(), 25)

        assert_not_called(Facts.fetch(:_, :_))
      end

      assert 0 == Folder.folded_height(State.new())
    end

    test "it doesn't move on when a generation can't be read" do
      with_mock Facts,
        fetch: fn
          _state, 2 -> {:error, :chain_too_short}
          _state, height -> {:ok, facts(height)}
        end do
        assert_raise RuntimeError, fn -> Folder.fold_chunk(State.new(), 3) end

        assert 0 == Folder.folded_height(State.new())
        assert :not_found = State.get(State.new(), Model.MinerEntity, {:miner, <<1::256>>})
      end
    end
  end

  defp facts(height) do
    %{
      height: height,
      time: height * 1_000,
      miner: <<1::256>>,
      beneficiary: <<2::256>>,
      difficulty: 100,
      micro_blocks: 1,
      txs: 1,
      fees: 10,
      rewards: %{}
    }
  end
end
