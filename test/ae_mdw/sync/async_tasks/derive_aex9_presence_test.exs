defmodule AeMdw.Sync.AsyncTasks.DeriveAex9PresenceTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.DeriveAex9Presence
  alias AeMdw.Validate

  import Mock

  require Model

  describe "process/1" do
    test "writes aex9 presence and balance" do
      kbi = 319_506
      mbi = 101
      create_txi = 16_063_684
      amount1 = 323_838_000_000_000_000_000
      amount2 = 198_554_400_000_000_000_000
      kb_hash = Validate.id!("kh_2DQZpzmoTVvUUtRtLsamt2j6cN43YRcMtP6S8YCMehZ8DAbety")

      next_mb_hash = Validate.id!("mh_2ShoazmibMsaaLfY9wnENSxJJATcD2HtyjHQPn9JCnUbsGPY18")
      contract_pk = Validate.id("ct_ypGRSB6gEy8koLg6a4WRdShTfRsh9HfkMkxsE2SMCBk3JdkNP")
      account_pk1 = Validate.id!("ak_2EETVuL9MaN8XjzeKVn42swLSf3fHpUTDMK1CEHnckRNKeK8z5")
      account_pk2 = Validate.id!("ak_2pwi3Dqwmx84FMwU1KFUmnxpEABAkSo5L2o4LhAxWZBs9c57kX")

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn height ->
             assert ^height = kbi + 1
             kb_hash
           end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^contract_pk, {nil, ^kbi, ^next_mb_hash} = block_tuple ->
             balances = %{
               {:address, account_pk1} => amount1,
               {:address, account_pk2} => amount2
             }

             {balances, block_tuple}
           end
         ]}
      ] do
        DeriveAex9Presence.process([contract_pk, kbi, mbi, create_txi])

        assert Model.aex9_balance(txi: ^create_txi, amount: ^amount1) =
                 Database.fetch!(Model.Aex9Balance, {contract_pk, account_pk1})

        assert Model.aex9_balance(txi: ^create_txi, amount: ^amount2) =
                 Database.fetch!(Model.Aex9Balance, {contract_pk, account_pk2})

        assert Database.exists?(Model.Aex9AccountPresence, {account_pk1, create_txi, contract_pk})
        assert Database.exists?(Model.Aex9AccountPresence, {account_pk2, create_txi, contract_pk})
      end
    end
  end
end
