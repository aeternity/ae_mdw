defmodule AeMdw.Sync.AsyncTasks.WealthRankAccountsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Sync.AsyncTasks.WealthRankAccounts

  describe "micro_block_accounts/2" do
    test "returns a set of transaction and internal call accounts" do
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      account_pk3 = :crypto.strong_rand_bytes(32)
      account_pk4 = :crypto.strong_rand_bytes(32)
      account_pk5 = :crypto.strong_rand_bytes(32)

      {:ok, aetx1} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, account_pk1),
          recipient_id: :aeser_id.create(:account, account_pk2),
          amount: 123,
          fee: 0,
          nonce: 1,
          payload: <<>>
        })

      txs = [
        :aetx_sign.new(aetx1, [])
      ]

      micro_block =
        :aec_blocks.new_micro(
          1,
          <<0::256>>,
          <<1::256>>,
          <<>>,
          <<>>,
          txs,
          System.system_time(),
          :no_fraud,
          0
        )

      {:ok, aetx2} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, account_pk3),
          recipient_id: :aeser_id.create(:account, account_pk4),
          amount: 123,
          fee: 0,
          nonce: 2,
          payload: <<>>
        })

      {:ok, aetx3} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, account_pk1),
          recipient_id: :aeser_id.create(:account, account_pk5),
          amount: 123,
          fee: 0,
          nonce: 2,
          payload: <<>>
        })

      {tx_type2, tx_rec2} = :aetx.specialize_type(aetx2)
      {tx_type3, tx_rec3} = :aetx.specialize_type(aetx3)

      int_calls = [
        {0, "Chain.spend", tx_type2, aetx2, tx_rec2},
        {1, "Call.amount", tx_type3, aetx3, tx_rec3}
      ]

      mutations = [IntCallsMutation.new(:crypto.strong_rand_bytes(32), 1, int_calls)]

      assert MapSet.equal?(
               MapSet.new([account_pk1, account_pk2, account_pk3, account_pk4, account_pk5]),
               WealthRankAccounts.micro_block_accounts(micro_block, mutations)
             )
    end
  end
end
