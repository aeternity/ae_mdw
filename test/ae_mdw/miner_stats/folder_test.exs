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
    Model.MinerLink,
    Model.BeneficiaryLink,
    Model.NetworkBucket,
    Model.DeltaStat,
    Model.Stat
  ]

  setup do
    Enum.each(1..3, &Database.dirty_write(Model.DeltaStat, Model.delta_stat(index: &1)))

    on_exit(fn ->
      Enum.each(@tables, fn table ->
        table |> Database.all_keys() |> Enum.each(&Database.dirty_delete(table, &1))
      end)
    end)
  end

  describe "fold_chunk/2" do
    test "it folds each finalized generation only once, in chunks" do
      with_mock Facts, fetch: fn _state, height -> {:ok, facts(height)} end do
        assert 0 == Folder.folded_height(State.new())

        assert :more = Folder.fold_chunk(State.new(), 2)
        assert 2 == Folder.folded_height(State.new())
        assert_called_exactly(Facts.fetch(:_, :_), 2)

        assert :caught_up = Folder.fold_chunk(State.new(), 2)
        assert 3 == Folder.folded_height(State.new())

        assert :caught_up = Folder.fold_chunk(State.new(), 2)
        assert_called_exactly(Facts.fetch(:_, :_), 3)
      end

      assert {:ok, Model.miner_entity(blocks: 3, first_height: 1, last_height: 3)} =
               State.get(State.new(), Model.MinerEntity, {:miner, <<1::256>>})

      assert {:ok, Model.network_bucket(blocks: 3, blocks_total: 3)} =
               State.get(State.new(), Model.NetworkBucket, {1, 0})
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
      info: nil,
      difficulty: 100,
      micro_blocks: 1,
      txs: 1,
      fees: 10,
      rewards: %{}
    }
  end
end
