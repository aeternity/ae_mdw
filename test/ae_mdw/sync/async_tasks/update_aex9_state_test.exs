defmodule AeMdw.Sync.AsyncTasks.UpdateAex9StateTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Sync.Aex9BalancesCache
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Stats
  alias AeMdw.Sync.AsyncTasks.UpdateAex9State

  import Mock

  require Model

  @account_pk1 <<100_000_000_001_001::256>>
  @account_pk2 <<100_000_000_001_002::256>>

  @amount1 Enum.random(1_000_000_000..9_999_999_999)
  @amount2 Enum.random(1_000_000_000..9_999_999_999)

  @balances1 %{
    {:address, @account_pk1} => @amount1,
    {:address, @account_pk2} => @amount2
  }

  @contract_pk1 <<100_000_000_001_003::256>>
  @contract_pk2 <<100_000_000_001_004::256>>
  @contract_pk3 <<100_000_000_001_005::256>>
  @inexisting_pk :crypto.strong_rand_bytes(32)

  @kb_hash :crypto.strong_rand_bytes(32)
  @next_hash :crypto.strong_rand_bytes(32)

  describe "process/1" do
    test "updates aex9 presence and balance" do
      contract_pk = @contract_pk1
      block_index = {kbi, mbi} = {Enum.random(1..999_999), 11}
      next_height = kbi + 1
      kb_hash = @kb_hash
      next_hash = @next_hash
      call_txi = 12_345_679
      amount1 = @amount1
      amount2 = @amount2

      with_mocks([
        {AeMdw.Node.Db, [:passthrough],
         [
           get_key_block_hash: fn ^next_height -> kb_hash end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_hash} ->
             {:ok, @balances1}
           end
         ]}
      ]) do
        assert :ok = UpdateAex9State.process([contract_pk, block_index, call_txi], fn -> :ok end)

        state = State.new(AsyncStore.instance())

        Enum.any?(1..10, fn _i ->
          Process.sleep(100)

          assert Model.aex9_event_balance(txi: ^call_txi, amount: ^amount1) =
                   State.fetch!(state, Model.Aex9EventBalance, {contract_pk, @account_pk1})
        end)

        assert Model.aex9_event_balance(txi: ^call_txi, amount: ^amount2) =
                 State.fetch!(state, Model.Aex9EventBalance, {contract_pk, @account_pk2})

        assert Model.aex9_account_presence(txi: ^call_txi) =
                 State.fetch!(state, Model.Aex9AccountPresence, {@account_pk1, contract_pk})

        assert Model.aex9_account_presence(txi: ^call_txi) =
                 State.fetch!(state, Model.Aex9AccountPresence, {@account_pk2, contract_pk})
      end
    end

    test "creates empty balance when contract has no balance" do
      contract_pk = @contract_pk2
      block_index = {kbi, mbi} = {Enum.random(1..999_999), 12}
      next_height = kbi + 1
      kb_hash = @kb_hash
      next_hash = @next_hash
      call_txi = 12_345_680

      with_mocks([
        {AeMdw.Node.Db, [:passthrough],
         [
           get_key_block_hash: fn ^next_height -> kb_hash end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_hash} ->
             {:ok, %{}}
           end
         ]}
      ]) do
        assert :ok = UpdateAex9State.process([contract_pk, block_index, call_txi], fn -> :ok end)

        state = State.new(AsyncStore.instance())

        assert Enum.any?(1..10, fn _i ->
                 Process.sleep(100)
                 State.exists?(state, Model.Aex9EventBalance, {contract_pk, <<>>})
               end)
      end
    end

    test "uses cached aex9 balances when already dry-runned" do
      contract_pk = @contract_pk3
      block_index = {kbi, mbi} = {Enum.random(1..999_999), 12}
      next_height = kbi + 1
      kb_hash = @kb_hash
      next_hash = @next_hash
      call_txi = 12_345_681

      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)

      amount1 = Enum.random(1_000_000_000..9_999_999_999)
      amount2 = Enum.random(1_000_000_000..9_999_999_999)

      Aex9BalancesCache.put(contract_pk, block_index, @next_hash, %{
        {:address, account_pk1} => amount1,
        {:address, account_pk2} => amount2
      })

      with_mocks([
        {AeMdw.Node.Db, [:passthrough],
         [
           get_key_block_hash: fn ^next_height -> kb_hash end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_hash} ->
             {:ok, %{}}
           end
         ]}
      ]) do
        assert :ok = UpdateAex9State.process([contract_pk, block_index, call_txi], fn -> :ok end)
        state = State.new(AsyncStore.instance())

        Enum.any?(1..10, fn _i ->
          Process.sleep(100)

          assert Model.aex9_event_balance(txi: ^call_txi, amount: ^amount1) =
                   State.fetch!(state, Model.Aex9EventBalance, {contract_pk, account_pk1})
        end)

        assert Model.aex9_event_balance(txi: ^call_txi, amount: ^amount2) =
                 State.fetch!(state, Model.Aex9EventBalance, {contract_pk, account_pk2})

        refute State.exists?(state, Model.Aex9EventBalance, {contract_pk, <<>>})
      end
    end

    test "recounts the holders on the database once the async store is written to it" do
      contract_pk = :crypto.strong_rand_bytes(32)
      creator_pk = :crypto.strong_rand_bytes(32)
      holder_pk = :crypto.strong_rand_bytes(32)
      block_index = {kbi, mbi} = {Enum.random(1..999_999), 13}
      next_height = kbi + 1
      kb_hash = @kb_hash
      next_hash = @next_hash
      call_txi = 12_345_683
      test_pid = self()
      holders_key = Stats.aex9_holder_count_key(contract_pk)

      # a mint after the creation already added a holder on the database
      Database.dirty_write(
        Model.Aex9EventBalance,
        Model.aex9_event_balance(
          index: {contract_pk, holder_pk},
          txi: call_txi + 1,
          log_idx: 0,
          amount: 100
        )
      )

      Database.dirty_write(Model.Stat, Model.stat(index: holders_key, payload: 1))

      on_exit(fn ->
        Database.dirty_delete(Model.Aex9EventBalance, {contract_pk, holder_pk})
        Database.dirty_delete(Model.Aex9EventBalance, {contract_pk, creator_pk})
        Database.dirty_delete(Model.Aex9BalanceAccount, {contract_pk, 1_000, creator_pk})
        Database.dirty_delete(Model.Aex9AccountPresence, {creator_pk, contract_pk})
        Database.dirty_delete(Model.Aex9InitialSupply, contract_pk)
        Database.dirty_delete(Model.Aex9ContractBalance, contract_pk)
        Database.dirty_delete(Model.Stat, holders_key)
      end)

      with_mocks([
        {AeMdw.Node.Db, [:passthrough],
         [
           get_key_block_hash: fn ^next_height -> kb_hash end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_hash} ->
             {:ok, %{{:address, creator_pk} => 1_000}}
           end
         ]}
      ]) do
        UpdateAex9State.process([contract_pk, block_index, call_txi], fn ->
          send(test_pid, :written)
        end)

        assert_receive :written
      end

      # the async store only counts the creator, it can't see the mint
      assert {:ok, Model.stat(payload: 1)} =
               State.get(State.new(AsyncStore.instance()), Model.Stat, holders_key)

      _state = State.commit(State.new(), [])

      assert 2 == Stats.fetch_aex9_holders_count(State.new(), contract_pk)
    end

    test "discards a task for not present contract" do
      contract_pk = @inexisting_pk
      unique_msg = System.unique_integer()
      done_fn = fn -> send(self(), unique_msg) end
      block_index = {kbi, mbi} = {Enum.random(1..999_999), 12}
      next_height = kbi + 1
      kb_hash = @kb_hash
      next_hash = @next_hash
      call_txi = 12_345_682

      with_mocks([
        {AeMdw.Node.Db, [:passthrough],
         [
           get_key_block_hash: fn ^next_height -> kb_hash end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_hash} ->
             {:error, :contract_does_not_exist}
           end
         ]}
      ]) do
        UpdateAex9State.process([contract_pk, block_index, call_txi], done_fn)

        assert_receive ^unique_msg
      end
    end
  end
end
