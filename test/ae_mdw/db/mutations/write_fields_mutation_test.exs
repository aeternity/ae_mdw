defmodule AeMdw.Db.WriteFieldsMuationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Store
  alias AeMdw.Db.State
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.WriteFieldsMutation
  alias AeMdw.Fields
  alias AeMdw.Validate

  import Mock
  import AeMdw.TestUtil, only: [change_store: 2]

  require Model

  @fake_account "ak_pZBf4crWhZvdgJzpX996N7wmb9aD4EZbWCfGysQ8mNRCfEvvi"
  @fake_account2 "ak_2nF3Lh7djksbWLzXoNo6x59hnkyBezK8yjR53GPFgha3VdM1K8"
  @fake_mb "mh_2XGZtE8jxUs2NymKHsytkaLLrk6KY2t2w1FjJxtAUqYZn8Wsdd"

  setup do
    global_state_ref = :persistent_term.get(:global_state, nil)
    on_exit(fn -> :persistent_term.put(:global_state, global_state_ref) end)
  end

  describe "execute/1" do
    test "when tx_type = :spend_tx and id is a name, it fetches the block from the store" do
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

      store =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(Model.Block, block)

      mutation = WriteFieldsMutation.new(:spend_tx, spend_tx, block_index, txi)

      with_mocks [
        {Name, [:passthrough],
         [
           ptr_resolve: fn _store, _block_index, _name_hash, "account_pubkey" ->
             {:ok, Validate.id!(@fake_account2)}
           end
         ]}
      ] do
        store2 = change_store(store, [mutation])

        assert {:ok, Model.field(index: ^field_index1)} =
                 Store.get(store2, Model.Field, field_index1)

        assert {:ok, Model.field(index: ^field_index2)} =
                 Store.get(store2, Model.Field, field_index2)

        assert {:ok, Model.account_counter(txs: 1, activities: 1)} =
                 Store.get(store2, Model.AccountCounter, account_pk)

        assert {:ok, Model.account_counter(txs: 1, activities: 1)} =
                 Store.get(store2, Model.AccountCounter, account_pk2)
      end
    end

    test "indexes inner transaction fields with ga_meta_tx type" do
      sender_pk = :crypto.strong_rand_bytes(32)
      recipient_pk = :crypto.strong_rand_bytes(32)

      {:ok, aetx} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, sender_pk),
          recipient_id: :aeser_id.create(:account, recipient_pk),
          amount: 123,
          fee: 456,
          nonce: 1,
          payload: ""
        })

      {:spend_tx, spend_tx} = :aetx.specialize_type(aetx)
      txi = 123

      store =
        NullStore.new()
        |> MemStore.new()
        |> change_store([
          WriteFieldsMutation.new(:spend_tx, spend_tx, {100_000, 1}, txi, :ga_meta_tx)
        ])

      field_index1 = {:ga_meta_tx, Fields.field_pos_mask(:ga_meta_tx, 1), sender_pk, txi}
      field_index2 = {:ga_meta_tx, Fields.field_pos_mask(:ga_meta_tx, 2), recipient_pk, txi}

      refute :not_found == Store.get(store, Model.Field, field_index1)
      refute :not_found == Store.get(store, Model.Field, field_index2)

      assert {:ok, Model.account_counter(txs: 1, activities: 1)} =
               Store.get(store, Model.AccountCounter, sender_pk)

      assert {:ok, Model.account_counter(txs: 1, activities: 1)} =
               Store.get(store, Model.AccountCounter, recipient_pk)
    end

    test "indexes inner transaction fields with paying_for type" do
      sender_pk = :crypto.strong_rand_bytes(32)
      recipient_pk = :crypto.strong_rand_bytes(32)

      {:ok, aetx} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, sender_pk),
          recipient_id: :aeser_id.create(:account, recipient_pk),
          amount: 123,
          fee: 456,
          nonce: 1,
          payload: ""
        })

      {:spend_tx, spend_tx} = :aetx.specialize_type(aetx)
      txi = 123

      store =
        NullStore.new()
        |> MemStore.new()
        |> change_store([
          WriteFieldsMutation.new(:spend_tx, spend_tx, {100_000, 1}, txi, :paying_for_tx)
        ])

      field_index1 = {:paying_for_tx, Fields.field_pos_mask(:paying_for_tx, 1), sender_pk, txi}

      field_index2 = {:paying_for_tx, Fields.field_pos_mask(:paying_for_tx, 2), recipient_pk, txi}

      refute :not_found == Store.get(store, Model.Field, field_index1)
      refute :not_found == Store.get(store, Model.Field, field_index2)

      assert {:ok, Model.account_counter(txs: 1, activities: 1)} =
               Store.get(store, Model.AccountCounter, sender_pk)

      assert {:ok, Model.account_counter(txs: 1, activities: 1)} =
               Store.get(store, Model.AccountCounter, recipient_pk)
    end

    test "increments counters for each field, including dups" do
      sender_pk = :crypto.strong_rand_bytes(32)
      recipient_pk = :crypto.strong_rand_bytes(32)
      [txi1, txi2] = [123, 124]

      {:ok, aetx1} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, sender_pk),
          recipient_id: :aeser_id.create(:account, recipient_pk),
          amount: 123,
          fee: 456,
          nonce: 1,
          payload: ""
        })

      {:spend_tx, spend_tx1} = :aetx.specialize_type(aetx1)

      {:ok, aetx2} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, sender_pk),
          recipient_id: :aeser_id.create(:account, sender_pk),
          amount: 123,
          fee: 456,
          nonce: 1,
          payload: ""
        })

      {:spend_tx, spend_tx2} = :aetx.specialize_type(aetx2)

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.commit_mem([
          WriteFieldsMutation.new(:spend_tx, spend_tx1, {100_000, 1}, txi1, nil),
          WriteFieldsMutation.new(:spend_tx, spend_tx2, {100_000, 1}, txi2, nil)
        ])

      field_index1 = {:spend_tx, Fields.field_pos_mask(:spend_tx, 1), sender_pk, txi1}
      field_index2 = {:spend_tx, Fields.field_pos_mask(:spend_tx, 2), recipient_pk, txi1}
      field_index3 = {:spend_tx, Fields.field_pos_mask(:spend_tx, 1), sender_pk, txi2}
      field_index4 = {:spend_tx, Fields.field_pos_mask(:spend_tx, 2), sender_pk, txi2}
      id_count_index1 = {:spend_tx, Fields.field_pos_mask(:spend_tx, 1), sender_pk}
      id_count_index2 = {:spend_tx, Fields.field_pos_mask(:spend_tx, 2), sender_pk}

      assert {:ok, _field} = State.get(state, Model.Field, field_index1)
      assert {:ok, _field} = State.get(state, Model.Field, field_index2)
      assert {:ok, _field} = State.get(state, Model.Field, field_index3)
      assert {:ok, _field} = State.get(state, Model.Field, field_index4)
      assert {:ok, Model.id_count(count: 2)} = State.get(state, Model.IdCount, id_count_index1)
      assert {:ok, Model.id_count(count: 1)} = State.get(state, Model.DupIdCount, id_count_index1)
      assert {:ok, Model.id_count(count: 1)} = State.get(state, Model.IdCount, id_count_index2)
      assert {:ok, Model.id_count(count: 1)} = State.get(state, Model.DupIdCount, id_count_index2)

      assert {:ok, Model.account_counter(txs: 2, activities: 2)} =
               State.get(state, Model.AccountCounter, sender_pk)

      assert {:ok, Model.account_counter(txs: 1, activities: 1)} =
               State.get(state, Model.AccountCounter, recipient_pk)
    end
  end
end
