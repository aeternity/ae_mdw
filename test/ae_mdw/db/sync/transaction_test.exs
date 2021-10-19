defmodule AeMdw.Db.Sync.TransactionTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Node, as: AE

  alias AeMdw.Db.Sync.Transaction
  alias AeMdw.Db.Util
  alias AeMdw.Db.Model
  alias AeMdw.Validate

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, spend_tx: 3]
  import Mock

  require Ex2ms
  require Model

  @sender_id_pos AE.tx_ids(:spend_tx).sender_id
  @recipient_id_pos AE.tx_ids(:spend_tx).recipient_id

  describe "sync_transaction spend_tx" do
    test "when receiver and sender ids are different" do
      with_blockchain %{alice: 10_000, bob: 20_000},
        mb1: [
          t1: spend_tx(:alice, :bob, 5_000)
        ] do
        %{height: height, time: mb_time, txs: [tx_rec]} = blocks[:mb1]

        signed_tx = :aetx_sign.new(tx_rec, [])
        txi = Util.last_txi() + 1
        block_index = {height, 0}

        fn ->
          Transaction.sync_transaction(
            signed_tx,
            txi,
            {block_index, mb_time, nil},
            false
          )

          {sender_pk, recipient_pk} = pubkeys_from_tx(signed_tx)
          assert sender_pk != recipient_pk

          assert {:spend_tx, _pos, ^sender_pk, ^txi} =
                   query_spend_tx_field_index(sender_pk, @sender_id_pos)

          assert {:spend_tx, _pos, ^recipient_pk, ^txi} =
                   query_spend_tx_field_index(recipient_pk, @recipient_id_pos)

          :mnesia.abort(:rollback)
        end
        |> :mnesia.transaction()
        |> case do
          {:aborted, {%ExUnit.AssertionError{} = assertion_error, _stacktrace}} ->
            raise assertion_error

          {:aborted, :rollback} ->
            :pass

          other_result ->
            throw(other_result)
        end
      end
    end

    test "when receiver and sender ids are the same" do
      with_blockchain %{alice: 10_000},
        mb1: [
          t1: spend_tx(:alice, :alice, 5_000)
        ] do
        %{height: height, time: mb_time, txs: [tx_rec]} = blocks[:mb1]

        signed_tx = :aetx_sign.new(tx_rec, [])
        txi = Util.last_txi() + 1
        block_index = {height, 0}

        fn ->
          Transaction.sync_transaction(
            signed_tx,
            txi,
            {block_index, mb_time, nil},
            false
          )

          {sender_pk, recipient_pk} = pubkeys_from_tx(signed_tx)
          assert sender_pk == recipient_pk

          assert {:spend_tx, _pos, ^sender_pk, ^txi} =
                   query_spend_tx_field_index(sender_pk, @sender_id_pos)

          assert {:spend_tx, _pos, ^recipient_pk, ^txi} =
                   query_spend_tx_field_index(recipient_pk, @recipient_id_pos)

          :mnesia.abort(:rollback)
        end
        |> :mnesia.transaction()
        |> case do
          {:aborted, {%ExUnit.AssertionError{} = assertion_error, _stacktrace}} ->
            raise assertion_error

          {:aborted, :rollback} ->
            :pass

          other_result ->
            throw(other_result)
        end
      end
    end
  end

  #
  # Helper functions
  #
  defp pubkeys_from_tx(signed_tx) do
    {_mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    sender_pk = tx |> elem(@sender_id_pos) |> Validate.id!()
    recipient_pk = tx |> elem(@recipient_id_pos) |> Validate.id!()
    {sender_pk, recipient_pk}
  end

  defp query_spend_tx_field_index(pubkey, pos) do
    :mnesia.prev(Model.Field, {:spend_tx, pos, pubkey, nil})
  end
end
