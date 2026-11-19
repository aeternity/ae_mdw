defmodule AeMdw.Db.Sync.BlockTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Block
  alias AeMdw.Db.Sync.Transaction
  alias AeMdw.Db.WriteMutation

  import AeMdwWeb.BlockchainSim,
    only: [with_blockchain: 3, with_blockchain: 4, tx: 3, spend_tx: 3, name_tx: 3, name_tx: 4]

  import Mock

  require Model

  @mb_names ~w(mb0 mb1 mb2 mb3 mb4 mb5 mb6 mb7)a

  describe "blocks_mutations/4" do
    test "returns the mutations for a generation with many transactions" do
      # credo:disable-for-next-line
      accounts = Map.new(0..100, fn i -> {String.to_atom("user#{i}"), 100_000_000} end)

      first_microblock = {
        :mb0,
        List.flatten(
          Enum.map(1..30, fn i ->
            # credo:disable-for-next-line
            tx_tag = String.to_atom("tx#{i}")
            user = String.to_existing_atom("user#{i}")
            name = "name#{i}.chain"
            {tx_tag, name_tx(:name_claim_tx, user, name)}
          end) ++
            Enum.map(31..40, fn i ->
              # credo:disable-for-next-line
              tx_tag = String.to_atom("tx#{i}")
              user = String.to_existing_atom("user#{i}")
              {tx_tag, tx(:oracle_register_tx, user, %{})}
            end) ++
            Enum.map(41..100, fn i ->
              # credo:disable-for-next-line
              tx_tag = String.to_atom("tx#{i}")
              user = String.to_existing_atom("user#{i}")
              {tx_tag, spend_tx(user, user, 1_000)}
            end)
        )
      }

      microblocks =
        Enum.map(1..10, fn i ->
          # credo:disable-for-next-line
          mb_tag = String.to_atom("mb#{i}")
          user = String.to_existing_atom("user#{i}")
          oracle_id = :aeser_id.create(:oracle, <<i::256>>)

          {
            mb_tag,
            [
              tx1:
                name_tx(:name_update_tx, user, "name#{i}.chain", %{
                  pointers: [{:pointer, "account_pubkey", user}]
                }),
              tx2: {:oracle_query_tx, user, oracle_id, %{}}
            ] ++
              Enum.map(3..50, fn i ->
                tx_tag = String.to_existing_atom("tx#{i}")
                user = String.to_existing_atom("user#{i}")
                {tx_tag, spend_tx(user, user, 1_000)}
              end)
          }
        end)

      with_blockchain accounts, [first_microblock | microblocks] do
        %{hash: last_mb_hash, height: 10} = blocks[:mb10]
        last_mb_hash = AeMdw.Validate.id!(last_mb_hash)

        assert mem1 = :ets.info(:sync_hashes, :memory)
        assert height_blocks = 0 |> Block.blocks_mutations(0, 0, last_mb_hash) |> Enum.to_list()
        assert ^height_blocks = 0 |> Block.blocks_mutations(0, 0, last_mb_hash) |> Enum.to_list()
        assert length(height_blocks) == 11
        assert mem2 = :ets.info(:sync_hashes, :memory)
        assert mem2 > mem1
      end
    end

    test "writes Model.Time only for the first and last tx of each micro block" do
      micro_blocks = [
        mb0: [
          tx0: spend_tx(:alice, :bob, 1),
          tx1: spend_tx(:alice, :bob, 2),
          tx2: spend_tx(:alice, :bob, 3)
        ],
        mb1: [tx3: spend_tx(:alice, :bob, 4)],
        mb2: []
      ]

      with_blockchain %{alice: 1_000_000_000, bob: 1_000_000_000}, [{0, micro_blocks}] do
        last_mb_hash = AeMdw.Validate.id!(blocks[:mb2].hash)

        assert [{0, blocks_mutations}] =
                 0 |> Block.blocks_mutations(0, 0, last_mb_hash, false) |> Enum.to_list()

        time_keys =
          for {_block_index, _block, mutations} <- blocks_mutations,
              %WriteMutation{table: Model.Time, record: Model.time(index: key)} <-
                List.flatten(mutations),
              do: key

        assert Enum.sort(time_keys) ==
                 Enum.sort([
                   {blocks[:mb0].time, 0},
                   {blocks[:mb0].time, 2},
                   {blocks[:mb1].time, 3}
                 ])
      end
    end

    test "replays the micro blocks of a generation concurrently, processing each in order with its own events" do
      restore_concurrency_on_exit()

      with_blockchain %{alice: 1_000_000_000, bob: 1_000_000_000},
                      [{0, micro_blocks(8)}],
                      [replay_mock(), processing_spy()] do
        mb_hashes = Enum.map(@mb_names, &AeMdw.Validate.id!(blocks[&1].hash))
        last_mb_hash = List.last(mb_hashes)

        [
          {serial, serial_pids, serial_processed},
          {concurrent, concurrent_pids, concurrent_processed}
        ] =
          for concurrency <- [1, 8] do
            Application.put_env(:ae_mdw, :sync_concurrency, concurrency)
            gens = 0 |> Block.blocks_mutations(0, 0, last_mb_hash, false) |> Enum.to_list()

            {gens, received(:replayed), received(:processed)}
          end

        assert [{0, blocks_mutations}] = serial
        assert Enum.map(blocks_mutations, &elem(&1, 0)) == Enum.map(0..7, &{0, &1}) ++ [{0, -1}]
        assert concurrent == serial
        assert serial_processed == Enum.map(mb_hashes, &{&1, %{replayed: &1}})
        assert concurrent_processed == serial_processed
        assert [self()] == Enum.uniq(serial_pids)
        assert length(concurrent_pids) == 8
        assert concurrent_pids |> Enum.uniq() |> length() > 1
      end
    end

    test "doesn't replay the micro blocks whose mutations are cached" do
      restore_concurrency_on_exit()
      Application.put_env(:ae_mdw, :sync_concurrency, 8)

      with_blockchain %{alice: 1_000_000_000, bob: 1_000_000_000},
                      [{0, micro_blocks(4)}],
                      [replay_mock()] do
        last_mb_hash = AeMdw.Validate.id!(blocks[:mb3].hash)

        gens = 0 |> Block.blocks_mutations(0, 0, last_mb_hash, true) |> Enum.to_list()
        assert length(received(:replayed)) == 4

        assert ^gens = 0 |> Block.blocks_mutations(0, 0, last_mb_hash, true) |> Enum.to_list()
        assert [] == received(:replayed)
      end
    end
  end

  # random amounts, so that no other test cached the same micro blocks
  defp micro_blocks(count) do
    @mb_names
    |> Enum.zip(~w(tx0 tx1 tx2 tx3 tx4 tx5 tx6 tx7)a)
    |> Enum.take(count)
    |> Enum.map(fn {mb_name, tx_name} ->
      {mb_name, [{tx_name, spend_tx(:alice, :bob, Enum.random(1..1_000_000))}]}
    end)
  end

  defp replay_mock do
    test_pid = self()

    {AeMdw.Contract, [:passthrough],
     get_grouped_events: fn micro_block ->
       send(test_pid, {:replayed, self()})
       Process.sleep(Enum.random(0..10))
       {:ok, mb_hash} = :aec_headers.hash_header(:aec_blocks.to_micro_header(micro_block))
       %{replayed: mb_hash}
     end}
  end

  defp processing_spy do
    test_pid = self()

    {Transaction, [:passthrough],
     transaction_mutations: fn signed_tx, txi, block_index, mb_hash, mb_time, events ->
       send(test_pid, {:processed, {mb_hash, events}})
       passthrough([signed_tx, txi, block_index, mb_hash, mb_time, events])
     end}
  end

  defp received(tag) do
    receive do
      {^tag, value} -> [value | received(tag)]
    after
      0 -> []
    end
  end

  defp restore_concurrency_on_exit do
    concurrency = Application.get_env(:ae_mdw, :sync_concurrency)
    on_exit(fn -> Application.put_env(:ae_mdw, :sync_concurrency, concurrency) end)
  end
end
