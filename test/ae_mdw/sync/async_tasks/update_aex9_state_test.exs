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
      total = amount1 + amount2

      on_exit(fn ->
        delete_aex9_rows(contract_pk, [{@account_pk1, amount1}, {@account_pk2, amount2}])
      end)

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
      end

      _state = State.commit(State.new(), [])
      state = State.new()

      assert Model.aex9_event_balance(txi: ^call_txi, amount: ^amount1) =
               State.fetch!(state, Model.Aex9EventBalance, {contract_pk, @account_pk1})

      assert Model.aex9_event_balance(txi: ^call_txi, amount: ^amount2) =
               State.fetch!(state, Model.Aex9EventBalance, {contract_pk, @account_pk2})

      assert Model.aex9_account_presence(txi: ^call_txi) =
               State.fetch!(state, Model.Aex9AccountPresence, {@account_pk1, contract_pk})

      assert Model.aex9_account_presence(txi: ^call_txi) =
               State.fetch!(state, Model.Aex9AccountPresence, {@account_pk2, contract_pk})

      assert Model.aex9_contract_balance(amount: ^total) =
               State.fetch!(state, Model.Aex9ContractBalance, contract_pk)

      assert 2 == Stats.fetch_aex9_holders_count(state, contract_pk)
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

      on_exit(fn ->
        delete_aex9_rows(contract_pk, [{account_pk1, amount1}, {account_pk2, amount2}])
      end)

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
      end

      _state = State.commit(State.new(), [])
      state = State.new()

      assert Model.aex9_event_balance(txi: ^call_txi, amount: ^amount1) =
               State.fetch!(state, Model.Aex9EventBalance, {contract_pk, account_pk1})

      assert Model.aex9_event_balance(txi: ^call_txi, amount: ^amount2) =
               State.fetch!(state, Model.Aex9EventBalance, {contract_pk, account_pk2})

      refute State.exists?(state, Model.Aex9EventBalance, {contract_pk, <<>>})
    end

    test "keeps the balances events refreshed after the creation" do
      contract_pk = :crypto.strong_rand_bytes(32)
      creator_pk = :crypto.strong_rand_bytes(32)
      holder_pk = :crypto.strong_rand_bytes(32)
      other_pk = :crypto.strong_rand_bytes(32)
      block_index = {kbi, mbi} = {Enum.random(1..999_999), 13}
      next_height = kbi + 1
      kb_hash = @kb_hash
      next_hash = @next_hash
      call_txi = 12_345_683

      # since the creation the creator sent 300 to the holder, who also got 100 minted
      events_balances = [{creator_pk, 700, call_txi + 1}, {holder_pk, 400, call_txi + 2}]

      Enum.each(events_balances, fn {account_pk, amount, txi} ->
        Database.dirty_write(
          Model.Aex9EventBalance,
          Model.aex9_event_balance(
            index: {contract_pk, account_pk},
            txi: txi,
            log_idx: 0,
            amount: amount
          )
        )

        Database.dirty_write(
          Model.Aex9BalanceAccount,
          Model.aex9_balance_account(index: {contract_pk, amount, account_pk}, txi: txi)
        )
      end)

      Database.dirty_write(
        Model.Aex9ContractBalance,
        Model.aex9_contract_balance(index: contract_pk, amount: 1_100)
      )

      Database.dirty_write(
        Model.Stat,
        Model.stat(index: Stats.aex9_holder_count_key(contract_pk), payload: 2)
      )

      on_exit(fn ->
        delete_aex9_rows(contract_pk, [
          {creator_pk, 700},
          {creator_pk, 1_000},
          {holder_pk, 400},
          {other_pk, 50}
        ])
      end)

      with_mocks([
        {AeMdw.Node.Db, [:passthrough],
         [
           get_key_block_hash: fn ^next_height -> kb_hash end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_hash} ->
             {:ok, %{{:address, creator_pk} => 1_000, {:address, other_pk} => 50}}
           end
         ]}
      ]) do
        assert :ok = UpdateAex9State.process([contract_pk, block_index, call_txi], fn -> :ok end)
      end

      _state = State.commit(State.new(), [])
      state = State.new()

      creator_txi = call_txi + 1

      assert Model.aex9_event_balance(txi: ^creator_txi, amount: 700) =
               State.fetch!(state, Model.Aex9EventBalance, {contract_pk, creator_pk})

      assert Model.aex9_event_balance(amount: 400) =
               State.fetch!(state, Model.Aex9EventBalance, {contract_pk, holder_pk})

      assert Model.aex9_event_balance(txi: ^call_txi, log_idx: -1, amount: 50) =
               State.fetch!(state, Model.Aex9EventBalance, {contract_pk, other_pk})

      refute State.exists?(state, Model.Aex9BalanceAccount, {contract_pk, 1_000, creator_pk})
      assert State.exists?(state, Model.Aex9BalanceAccount, {contract_pk, 700, creator_pk})
      assert State.exists?(state, Model.Aex9BalanceAccount, {contract_pk, 50, other_pk})

      assert Model.aex9_contract_balance(amount: 1_150) =
               State.fetch!(state, Model.Aex9ContractBalance, contract_pk)

      assert Model.aex9_initial_supply(amount: 1_050) =
               State.fetch!(state, Model.Aex9InitialSupply, contract_pk)

      assert 3 == Stats.fetch_aex9_holders_count(state, contract_pk)
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

  defp delete_aex9_rows(contract_pk, balances) do
    Enum.each(balances, fn {account_pk, amount} ->
      Database.dirty_delete(Model.Aex9EventBalance, {contract_pk, account_pk})
      Database.dirty_delete(Model.Aex9BalanceAccount, {contract_pk, amount, account_pk})
      Database.dirty_delete(Model.Aex9AccountPresence, {account_pk, contract_pk})
    end)

    Database.dirty_delete(Model.Aex9InitialSupply, contract_pk)
    Database.dirty_delete(Model.Aex9ContractBalance, contract_pk)
    Database.dirty_delete(Model.Stat, Stats.aex9_holder_count_key(contract_pk))
  end
end
