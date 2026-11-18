defmodule AeMdw.Sync.Aex9BalancesTest do
  use ExUnit.Case, async: false

  alias AeMdw.Sync.Aex9AccountBalancesCache
  alias AeMdw.Sync.Aex9Balances
  alias AeMdw.Sync.Aex9BalancesCache

  import AeMdw.Node.ContractCallFixtures, only: [call_rec: 5]
  import AeMdw.Node.AexnEventFixtures, only: [aexn_event_hash: 1]
  import ExUnit.CaptureLog, only: [with_log: 1]
  import Mock

  describe "get_balances/2" do
    test "returns the balances cached for a forked block as purged, once" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      block_index = {kbi, mbi} = {Enum.random(100_000..999_999), 1}
      next_height = kbi + 1
      kb_hash = :crypto.strong_rand_bytes(32)
      next_hash = :crypto.strong_rand_bytes(32)
      forked_hash = :crypto.strong_rand_bytes(32)

      Aex9BalancesCache.put(contract_pk, block_index, forked_hash, %{
        {:address, account_pk1} => 10
      })

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           get_key_block_hash: fn ^next_height -> kb_hash end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_hash} ->
             {:ok, %{{:address, account_pk2} => 20}}
           end
         ]}
      ] do
        assert {:ok, [{^account_pk2, 20}], [{^account_pk1, 10}]} =
                 Aex9Balances.get_balances(contract_pk, block_index)

        assert {:ok, [{^account_pk2, 20}], []} =
                 Aex9Balances.get_balances(contract_pk, block_index)

        assert :not_found = Aex9BalancesCache.get(contract_pk, block_index, forked_hash)
        assert_called_exactly(AeMdw.Node.Db.aex9_balances(contract_pk, :_), 1)
      end
    end
  end

  describe "get_balance/4" do
    test "doesn't reuse the balance of a forked micro block" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      block_index = {kbi, _mbi} = {Enum.random(100_000..999_999), 1}
      fork_height_hash = {:micro, kbi, :crypto.strong_rand_bytes(32)}
      height_hash = {:micro, kbi, :crypto.strong_rand_bytes(32)}

      with_mock AeMdw.Node.Db, [:passthrough],
        aex9_balance: fn
          ^contract_pk, ^account_pk, ^fork_height_hash -> {:ok, {10, fork_height_hash}}
          ^contract_pk, ^account_pk, ^height_hash -> {:ok, {20, height_hash}}
        end do
        assert {:ok, 10} =
                 Aex9Balances.get_balance(contract_pk, account_pk, block_index, fork_height_hash)

        assert {:ok, 20} =
                 Aex9Balances.get_balance(contract_pk, account_pk, block_index, height_hash)
      end
    end

    test "doesn't cache a failed dry-run" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      block_index = {kbi, _mbi} = {Enum.random(100_000..999_999), 1}
      height_hash = {:micro, kbi, :crypto.strong_rand_bytes(32)}

      with_mock AeMdw.Node.Db, [:passthrough],
        aex9_balance: fn ^contract_pk, ^account_pk, ^height_hash ->
          {:error, :dry_run_error}
        end do
        assert {:error, :dry_run_error} =
                 Aex9Balances.get_balance(contract_pk, account_pk, block_index, height_hash)
      end

      with_mock AeMdw.Node.Db, [:passthrough],
        aex9_balance: fn ^contract_pk, ^account_pk, ^height_hash ->
          {:ok, {20, height_hash}}
        end do
        assert {:ok, 20} =
                 Aex9Balances.get_balance(contract_pk, account_pk, block_index, height_hash)
      end
    end
  end

  describe "prefetch_balances/2" do
    test "caches the balances it gets, leaving out failed and cached ones" do
      test_pid = self()
      contract_pk = :crypto.strong_rand_bytes(32)
      put_aex9_type_info(contract_pk)
      [from_pk, to_pk, cached_pk, error_pk, crash_pk] = Enum.map(1..5, &<<&1::256>>)
      kbi = Enum.random(100_000..999_999)
      next_height = kbi + 1
      kb_hash = :crypto.strong_rand_bytes(32)
      next_hash0 = :crypto.strong_rand_bytes(32)
      next_hash1 = :crypto.strong_rand_bytes(32)
      Aex9AccountBalancesCache.put(contract_pk, {kbi, 0}, next_hash0, cached_pk, 7)

      call_rec0 =
        call_rec("logs", contract_pk, kbi, nil, [
          {contract_pk, [aexn_event_hash(:transfer), from_pk, to_pk, <<1::256>>], ""},
          {contract_pk, [aexn_event_hash(:mint), cached_pk, <<1::256>>], ""}
        ])

      call_rec1 =
        call_rec("logs", contract_pk, kbi, nil, [
          {contract_pk, [aexn_event_hash(:burn), error_pk, <<1::256>>], ""},
          {contract_pk, [aexn_event_hash(:mint), crash_pk, <<1::256>>], ""},
          {contract_pk, [aexn_event_hash(:mint), from_pk, <<1::256>>], ""}
        ])

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           get_key_block_hash: fn ^next_height -> kb_hash end,
           get_next_hash: fn
             ^kb_hash, 0 -> next_hash0
             ^kb_hash, 1 -> next_hash1
           end,
           aex9_balance: fn ^contract_pk, account_pk, {:micro, ^kbi, next_hash} = height_hash ->
             send(test_pid, {:dry_run, {account_pk, next_hash}})

             case account_pk do
               ^error_pk -> {:error, :dry_run_error}
               ^crash_pk -> raise "dry-run crashed"
               _other -> {:ok, {10, height_hash}}
             end
           end
         ]}
      ] do
        {keys, log} =
          with_log(fn ->
            Aex9Balances.prefetch_balances([{{kbi, 0}, [call_rec0]}, {{kbi, 1}, [call_rec1]}], 4)
          end)

        assert log =~ "[prefetch_balances] ** (RuntimeError) dry-run crashed"

        assert Enum.sort(keys) ==
                 Enum.sort([
                   {contract_pk, {kbi, 0}, next_hash0, from_pk},
                   {contract_pk, {kbi, 0}, next_hash0, to_pk},
                   {contract_pk, {kbi, 1}, next_hash1, from_pk}
                 ])

        assert Enum.sort(received_dry_runs()) ==
                 Enum.sort([
                   {from_pk, next_hash0},
                   {to_pk, next_hash0},
                   {error_pk, next_hash1},
                   {crash_pk, next_hash1},
                   {from_pk, next_hash1}
                 ])

        assert {:ok, 10} = Aex9AccountBalancesCache.get(contract_pk, {kbi, 0}, next_hash0, to_pk)

        assert {:ok, 7} =
                 Aex9AccountBalancesCache.get(contract_pk, {kbi, 0}, next_hash0, cached_pk)

        assert :not_found =
                 Aex9AccountBalancesCache.get(contract_pk, {kbi, 1}, next_hash1, error_pk)

        assert :not_found =
                 Aex9AccountBalancesCache.get(contract_pk, {kbi, 1}, next_hash1, crash_pk)

        assert :ok = Aex9Balances.delete_prefetched(keys)

        for {contract_pk, block_index, next_hash, account_pk} <- keys do
          assert :not_found =
                   Aex9AccountBalancesCache.get(contract_pk, block_index, next_hash, account_pk)
        end

        assert {:ok, 7} =
                 Aex9AccountBalancesCache.get(contract_pk, {kbi, 0}, next_hash0, cached_pk)
      end
    end
  end

  defp put_aex9_type_info(contract_pk) do
    functions =
      AeMdw.Node.aex9_signatures()
      |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

    AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {{:fcode, functions, nil, nil}, nil, nil})
  end

  defp received_dry_runs do
    receive do
      {:dry_run, dry_run} -> [dry_run | received_dry_runs()]
    after
      0 -> []
    end
  end
end
