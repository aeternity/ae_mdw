defmodule AeMdw.Db.WriteFieldsMuationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteFieldsMutation
  alias AeMdw.Validate

  import Mock

  require Model

  @fake_account "ak_pZBf4crWhZvdgJzpX996N7wmb9aD4EZbWCfGysQ8mNRCfEvvi"
  @fake_account2 "ak_2nF3Lh7djksbWLzXoNo6x59hnkyBezK8yjR53GPFgha3VdM1K8"
  @fake_mb "mh_2XGZtE8jxUs2NymKHsytkaLLrk6KY2t2w1FjJxtAUqYZn8Wsdd"

  describe "execute/1" do
    test "when tx_type = :spend_tx and id is a name, it fetches the block from the state" do
      block_index = {12, 3}
      block_hash = Validate.id!(@fake_mb)
      block = Model.block(index: block_index, hash: block_hash)
      txi = 123
      name_hash = :aens_hash.name_hash("asd.chain")
      account_pk = Validate.id!(@fake_account)
      account_pk2 = Validate.id!(@fake_account2)
      sender_id = :aeser_id.create(:account, account_pk)
      recipient_id = :aeser_id.create(:name, name_hash)
      field_index1 = {:spend_tx, 1, account_pk, txi}
      field_index2 = {:spend_tx, 2, account_pk2, txi}

      {:ok, aetx} =
        :aec_spend_tx.new(%{
          sender_id: sender_id,
          recipient_id: recipient_id,
          amount: 123,
          fee: 456,
          nonce: 0,
          payload: <<>>
        })

      {:spend_tx, spend_tx} = :aetx.specialize_type(aetx)

      Database.dirty_write(Model.Block, block)

      state = State.new()

      mutation = WriteFieldsMutation.new(:spend_tx, spend_tx, block_index, txi)

      with_mocks [
        {Name, [],
         [
           ptr_resolve!: fn _state, _block_index, _name_hash, _key ->
             Validate.id!(@fake_account2)
           end
         ]}
      ] do
        state2 = State.commit(state, [mutation])

        assert {:ok, Model.field(index: ^field_index1)} =
                 State.get(state2, Model.Field, field_index1)

        assert {:ok, Model.field(index: ^field_index2)} =
                 State.get(state2, Model.Field, field_index2)
      end
    end
  end
end
