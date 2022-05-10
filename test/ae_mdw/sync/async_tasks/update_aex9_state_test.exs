defmodule AeMdw.Sync.AsyncTasks.UpdateAex9StateTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Model
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
        :ets.insert(:aex9_sync_cache, {contract_pk, block_index, call_txi})
        UpdateAex9State.process([contract_pk])

        assert Model.aex9_balance(block_index: ^block_index, txi: ^call_txi, amount: ^amount1) =
                 Database.fetch!(Model.Aex9Balance, {contract_pk, account_pk1})

        assert Model.aex9_balance(block_index: ^block_index, txi: ^call_txi, amount: ^amount2) =
                 Database.fetch!(Model.Aex9Balance, {contract_pk, account_pk2})

        assert Database.exists?(Model.Aex9AccountPresence, {account_pk1, call_txi, contract_pk})
        assert Database.exists?(Model.Aex9AccountPresence, {account_pk2, call_txi, contract_pk})
      end
    end
  end
end
