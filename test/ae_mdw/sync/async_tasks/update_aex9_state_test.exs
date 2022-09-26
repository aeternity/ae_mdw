defmodule AeMdw.Sync.AsyncTasks.UpdateAex9StateTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Aex9BalancesCache
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
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

  @kbi 100_001
  @mbi 11
  @kb_hash :crypto.strong_rand_bytes(32)
  @next_hash :crypto.strong_rand_bytes(32)

  setup_with_mocks([
    {AeMdw.Node.Db, [],
     [
       get_key_block_hash: fn height ->
         assert ^height = @kbi + 1
         @kb_hash
       end,
       get_next_hash: fn kb_hash, mbi ->
         assert kb_hash == @kb_hash and mbi == @mbi
         @next_hash
       end,
       aex9_balances: fn contract_pk, next_hash_tuple ->
         assert next_hash_tuple == {:micro, @kbi, @next_hash}

         cond do
           contract_pk == @contract_pk1 ->
             {:ok, @balances1}

           contract_pk == @contract_pk2 ->
             {:ok, %{}}

           contract_pk == @inexisting_pk ->
             {:error, :contract_does_not_exist}
         end
       end
     ]}
  ]) do
    :ok
  end

  describe "process/1" do
    test "updates aex9 presence and balance" do
      block_index = {@kbi, @mbi}
      call_txi = 12_345_679
      amount1 = @amount1
      amount2 = @amount2

      assert :ok = UpdateAex9State.process([@contract_pk1, block_index, call_txi], fn -> :ok end)

      state = State.new(AsyncStore.instance())

      Enum.any?(1..10, fn _i ->
        Process.sleep(100)

        assert Model.aex9_balance(block_index: ^block_index, txi: ^call_txi, amount: ^amount1) =
                 State.fetch!(state, Model.Aex9Balance, {@contract_pk1, @account_pk1})
      end)

      assert Model.aex9_balance(block_index: ^block_index, txi: ^call_txi, amount: ^amount2) =
               State.fetch!(state, Model.Aex9Balance, {@contract_pk1, @account_pk2})

      assert Model.aex9_account_presence(txi: ^call_txi) =
               State.fetch!(state, Model.Aex9AccountPresence, {@account_pk1, @contract_pk1})

      assert Model.aex9_account_presence(txi: ^call_txi) =
               State.fetch!(state, Model.Aex9AccountPresence, {@account_pk2, @contract_pk1})
    end

    test "creates empty balance when contract has no balance" do
      block_index = {@kbi, @mbi}
      call_txi = 12_345_680

      assert :ok = UpdateAex9State.process([@contract_pk2, block_index, call_txi], fn -> :ok end)

      state = State.new(AsyncStore.instance())

      assert Enum.any?(1..10, fn _i ->
               Process.sleep(100)
               State.exists?(state, Model.Aex9Balance, {@contract_pk2, <<>>})
             end)
    end

    test "uses cached aex9 balances when already dry-runned" do
      block_index = {@kbi, @mbi}
      call_txi = 12_345_681

      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)

      amount1 = Enum.random(1_000_000_000..9_999_999_999)
      amount2 = Enum.random(1_000_000_000..9_999_999_999)

      Aex9BalancesCache.put(@contract_pk3, block_index, @next_hash, %{
        {:address, account_pk1} => amount1,
        {:address, account_pk2} => amount2
      })

      assert :ok = UpdateAex9State.process([@contract_pk3, {@kbi, @mbi}, call_txi], fn -> :ok end)
      state = State.new(AsyncStore.instance())

      Enum.any?(1..10, fn _i ->
        Process.sleep(100)

        assert Model.aex9_balance(block_index: ^block_index, txi: ^call_txi, amount: ^amount1) =
                 State.fetch!(state, Model.Aex9Balance, {@contract_pk3, account_pk1})
      end)

      assert Model.aex9_balance(block_index: ^block_index, txi: ^call_txi, amount: ^amount2) =
               State.fetch!(state, Model.Aex9Balance, {@contract_pk3, account_pk2})

      refute State.exists?(state, Model.Aex9Balance, {@contract_pk3, <<>>})
    end

    test "discards a task for not present contract" do
      unique_msg = System.unique_integer()
      done_fn = fn -> send(self(), unique_msg) end
      UpdateAex9State.process([@inexisting_pk, {@kbi, @mbi}, -1], done_fn)

      assert_receive ^unique_msg
    end
  end
end
