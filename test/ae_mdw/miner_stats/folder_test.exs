defmodule AeMdw.MinerStats.FolderTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Database
  alias AeMdw.Db.DbStore
  alias AeMdw.Db.Model
  alias AeMdw.MinerStats.Facts
  alias AeMdw.MinerStats.Folder
  alias AeMdw.Node.Db

  import Mock

  require Model

  @tables [
    Model.MinerEntity,
    Model.MinerOrder,
    Model.MinerBucket,
    Model.BucketMiner,
    Model.BeneficiaryLink,
    Model.NetworkBucket,
    Model.DeltaStat,
    Model.Stat,
    Model.Block,
    Model.Tx,
    Model.IntTransferTx,
    Model.KindIntTransferTx
  ]

  setup do
    keys_before = Map.new(@tables, &{&1, MapSet.new(Database.all_keys(&1))})

    on_exit(fn ->
      Enum.each(keys_before, fn {table, keys} ->
        table
        |> Database.all_keys()
        |> Enum.reject(&MapSet.member?(keys, &1))
        |> Enum.each(&Database.dirty_delete(table, &1))
      end)
    end)

    Enum.each(1..45, &Database.dirty_write(Model.DeltaStat, Model.delta_stat(index: &1)))
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
        assert_not_called(Facts.fetch(:_, 0))
      end

      assert {:ok, Model.miner_entity(blocks: 39, first_height: 1, last_height: 39)} =
               State.get(State.new(), Model.MinerEntity, {:miner, <<1::256>>})

      assert {:ok, Model.network_bucket(blocks: 20, blocks_total: 39)} =
               State.get(State.new(), Model.NetworkBucket, {:bucket, 1})
    end

    test "it waits for the first bucket to complete" do
      Enum.each(11..45, &Database.dirty_delete(Model.DeltaStat, &1))

      with_mock Facts, fetch: fn _state, height -> {:ok, facts(height)} end do
        assert {:caught_up, 9} = Folder.fold_chunk(State.new(), 25)

        assert_not_called(Facts.fetch(:_, :_))
      end

      assert 0 == Folder.folded_height(State.new())
    end

    test "it folds a bucket once the database has its last generation" do
      Enum.each(39..45, &Database.dirty_delete(Model.DeltaStat, &1))

      with_mock Facts, fetch: fn _state, height -> {:ok, facts(height)} end do
        assert {:caught_up, 1} = Folder.fold_chunk(State.new())
        assert 19 == Folder.folded_height(State.new())

        Database.dirty_write(Model.DeltaStat, Model.delta_stat(index: 39))

        assert {:caught_up, 20} = Folder.fold_chunk(State.new())
        assert 39 == Folder.folded_height(State.new())
      end
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

    test "it folds the generations of the database and serves them", %{conn: conn} do
      [m1, beneficiary, m3] = [<<1::256>>, <<2::256>>, <<3::256>>]

      # generation 5 has 2 txs and generation 6 has 1, in a micro block each
      Enum.each(1..40, fn height ->
        txi = if height <= 5, do: 0, else: min(height - 4, 3)
        Database.dirty_write(Model.Block, Model.block(index: {height, -1}, tx_index: txi))
      end)

      Database.dirty_write(Model.Block, Model.block(index: {5, 0}, tx_index: 0))
      Database.dirty_write(Model.Block, Model.block(index: {6, 0}, tx_index: 2))

      Enum.each([{0, 10}, {1, 20}, {2, 5}], fn {txi, fee} ->
        Database.dirty_write(Model.Tx, Model.tx(index: txi, fee: fee))
      end)

      Database.dirty_write(
        Model.IntTransferTx,
        Model.int_transfer_tx(index: {{30, -1}, "reward_block", beneficiary, -1}, amount: 1_000)
      )

      Database.dirty_write(
        Model.KindIntTransferTx,
        Model.kind_int_transfer_tx(index: {"reward_block", {30, -1}, beneficiary, -1})
      )

      with_mocks [
        {Db, [:passthrough],
         [
           get_key_header: fn height ->
             {:ok, header(height, if(height <= 20, do: m1, else: m3), beneficiary)}
           end
         ]},
        {:aec_headers, [:passthrough], [difficulty: fn _header -> 100 end]}
      ] do
        assert {:caught_up, 14} = Folder.fold_chunk(State.new())
      end

      conn = with_store(conn, DbStore.new())

      assert %{
               "stats_height" => 39,
               "last_bucket" => 1,
               "blocks" => 39,
               "txs" => 3,
               "fees" => 35,
               "rewards" => 1_000,
               "miners" => 2,
               "beneficiaries" => 1
             } = conn |> get("/v3/stats/mining") |> json_response(200)

      assert %{"role" => "miner", "first_height" => 1, "last_height" => 20, "blocks" => 20} =
               conn |> get("/v3/miners/#{id(m1)}") |> json_response(200)

      assert %{"role" => "beneficiary", "blocks" => 39, "txs" => 3, "rewards" => 1_000} =
               conn |> get("/v3/miners/#{id(beneficiary)}") |> json_response(200)

      assert %{"data" => [bucket1, bucket0]} =
               conn |> get("/v3/stats/mining/series") |> json_response(200)

      assert %{
               "bucket" => 1,
               "start_height" => 20,
               "end_height" => 39,
               "blocks" => 20,
               "rewards" => 1_000,
               "active_miners" => 2,
               "new_miners" => 1
             } = bucket1

      assert %{
               "bucket" => 0,
               "start_height" => 1,
               "end_height" => 19,
               "blocks" => 19,
               "micro_blocks" => 2,
               "txs" => 3,
               "fees" => 35
             } = bucket0
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

  defp header(height, miner, beneficiary) do
    height
    |> :aec_blocks.new_key(
      <<0::256>>,
      <<1::256>>,
      <<2::256>>,
      2,
      3,
      height * 1_000,
      :default,
      1,
      miner,
      beneficiary
    )
    |> :aec_blocks.to_key_header()
  end

  defp id(pk), do: :aeapi.format_account_pubkey(pk)
end
