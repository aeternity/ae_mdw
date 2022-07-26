defmodule AeMdw.Sync.AsyncTasks.UpdateAex9StateTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Aex9BalancesCache
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks.UpdateAex9State
  alias AeMdw.Validate

  import Mock

  require Model

  describe "process/1" do
    test "updates aex9 presence and balance" do
      kbi = 319_506
      mbi = 147
      block_index = {kbi, mbi}
      call_txi = 16_063_747
      amount1 = 323_838_000_000_000_000_000
      amount2 = 103_680_000_000_000_000_000
      kb_hash = Validate.id!("kh_2DQZpzmoTVvUUtRtLsamt2j6cN43YRcMtP6S8YCMehZ8DAbety")

      next_mb_hash = Validate.id!("mh_23nKM7w1YmDceMohUF7kgxfCgWbGM4kfjZsJtg1FoeYcqrzdMw")
      contract_pk = Validate.id("ct_ypGRSB6gEy8koLg6a4WRdShTfRsh9HfkMkxsE2SMCBk3JdkNP")
      account_pk1 = Validate.id!("ak_2g2yq6RniwW1cjKRu4HdVVQXa5GQZkBaXiaVogQXnRxUKpmhS")
      account_pk2 = Validate.id!("ak_24h4GD5wdWmQ5sLFADdZYKjEREMujbTAup5THvthcnPikYozq3")

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn height ->
             assert ^height = kbi + 1
             kb_hash
           end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_mb_hash} = block_tuple ->
             balances = %{
               {:address, account_pk1} => amount1,
               {:address, account_pk2} => amount2
             }

             {balances, block_tuple}
           end
         ]}
      ] do
        UpdateAex9State.process([contract_pk, block_index, call_txi, false])

        assert Model.aex9_balance(block_index: ^block_index, txi: ^call_txi, amount: ^amount1) =
                 Database.fetch!(Model.Aex9Balance, {contract_pk, account_pk1})

        assert Model.aex9_balance(block_index: ^block_index, txi: ^call_txi, amount: ^amount2) =
                 Database.fetch!(Model.Aex9Balance, {contract_pk, account_pk2})

        assert Model.aex9_account_presence(txi: ^call_txi) =
                 Database.fetch!(Model.Aex9AccountPresence, {account_pk1, contract_pk})

        assert Model.aex9_account_presence(txi: ^call_txi) =
                 Database.fetch!(Model.Aex9AccountPresence, {account_pk2, contract_pk})
      end
    end

    test "creates empty balance when contract has no balance" do
      kbi = 319_507
      mbi = 147
      block_index = {kbi, mbi}
      call_txi = 16_063_748
      kb_hash = :crypto.strong_rand_bytes(32)
      next_mb_hash = :crypto.strong_rand_bytes(32)
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn height ->
             assert ^height = kbi + 1
             kb_hash
           end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_mb_hash} = block_tuple ->
             {%{}, block_tuple}
           end
         ]}
      ] do
        UpdateAex9State.process([contract_pk, block_index, call_txi, false])
        assert Database.exists?(Model.Aex9Balance, {contract_pk, <<>>})
      end
    end

    test "uses cached aex9 balances when already dry-runned" do
      kbi = 123
      mbi = 1
      block_index = {kbi, mbi}
      call_txi = 123_456
      kb_hash = :crypto.strong_rand_bytes(32)
      next_mb_hash = :crypto.strong_rand_bytes(32)
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      amount1 = Enum.random(1_000_000..9_999_999)
      amount2 = Enum.random(1_000_000..9_999_999)

      Aex9BalancesCache.put(contract_pk, block_index, next_mb_hash, %{
        {:address, account_pk1} => amount1,
        {:address, account_pk2} => amount2
      })

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn height ->
             assert ^height = kbi + 1
             kb_hash
           end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_mb_hash} = block_tuple ->
             {%{}, block_tuple}
           end
         ]}
      ] do
        UpdateAex9State.process([contract_pk, block_index, call_txi, false])
        refute Database.exists?(Model.Aex9Balance, {contract_pk, <<>>})

        assert Model.aex9_balance(block_index: ^block_index, txi: ^call_txi, amount: ^amount1) =
                 Database.fetch!(Model.Aex9Balance, {contract_pk, account_pk1})

        assert Model.aex9_balance(block_index: ^block_index, txi: ^call_txi, amount: ^amount2) =
                 Database.fetch!(Model.Aex9Balance, {contract_pk, account_pk2})
      end
    end

    test "when async_store? = true, it saves aex9 state into ets store" do
      ct_pk = :crypto.strong_rand_bytes(32)
      {kbi, mbi} = block_index = {123_456, 2}
      next_kbi = kbi + 1
      call_txi = 12_345_678

      next_kb_hash = :crypto.strong_rand_bytes(32)
      next_mb_hash = :crypto.strong_rand_bytes(32)
      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000_000..9_999_999_999)

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn
             ^next_kbi ->
               next_kb_hash
           end,
           get_next_hash: fn ^next_kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^ct_pk, {:micro, ^kbi, ^next_mb_hash} ->
             balances = %{{:address, account_pk} => amount}

             {balances, nil}
           end
         ]}
      ] do
        UpdateAex9State.process([ct_pk, block_index, call_txi, true])

        ets_state = State.new(AsyncStore.instance())
        presence_key = {account_pk, ct_pk}
        balance_key = {ct_pk, account_pk}

        assert {:ok, Model.aex9_account_presence(index: ^presence_key, txi: ^call_txi)} =
                 State.get(ets_state, Model.Aex9AccountPresence, presence_key)

        assert {:ok,
                Model.aex9_balance(
                  index: ^balance_key,
                  block_index: ^block_index,
                  txi: ^call_txi,
                  amount: ^amount
                )} = State.get(ets_state, Model.Aex9Balance, balance_key)
      end
    end
  end
end
