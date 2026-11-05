defmodule AeMdw.Sync.Aex9BalancesTest do
  use ExUnit.Case, async: false

  alias AeMdw.Sync.Aex9Balances
  alias AeMdw.Sync.Aex9BalancesCache

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
end
