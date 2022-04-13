defmodule AeMdw.Db.Sync.TransactionTest do
  use ExUnit.Case, async: false

  alias AeMdw.Node, as: AE

  alias AeMdw.Database
  alias AeMdw.Contract
  alias AeMdw.Db.Sync.Transaction
  alias AeMdw.Db.Model
  alias AeMdw.Validate
  alias AeMdw.Db.Aex9CreateContractMutation

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, spend_tx: 3]
  import AeMdw.Node.ContractCallFixtures
  import Mock

  require Model

  @sender_id_pos AE.tx_ids(:spend_tx).sender_id
  @recipient_id_pos AE.tx_ids(:spend_tx).recipient_id
  @very_high_txi 100_000_000_000
  @create_pair_hash <<38, 76, 208, 75>>

  describe "sync_transaction spend_tx" do
    test "when receiver and sender ids are different" do
      with_blockchain %{alice: 10_000, bob: 20_000},
        mb1: [
          t1: spend_tx(:alice, :bob, 5_000)
        ] do
        %{height: height, block: mb, time: mb_time, txs: [tx_rec]} = blocks[:mb1]

        signed_tx = :aetx_sign.new(tx_rec, [])
        txi = @very_high_txi + 1
        block_index = {height, 0}

        txn_mutations =
          Transaction.transaction_mutations(
            signed_tx,
            txi,
            {block_index, mb, mb_time, %{}},
            false
          )

        Database.commit(txn_mutations)

        {sender_pk, recipient_pk} = pubkeys_from_tx(signed_tx)
        assert sender_pk != recipient_pk

        assert {:spend_tx, _pos, ^sender_pk, ^txi} =
                 query_spend_tx_field_index(sender_pk, @sender_id_pos)

        assert {:spend_tx, _pos, ^recipient_pk, ^txi} =
                 query_spend_tx_field_index(recipient_pk, @recipient_id_pos)
      end
    end

    test "when receiver and sender ids are the same" do
      with_blockchain %{alice: 10_000},
        mb1: [
          t1: spend_tx(:alice, :alice, 5_000)
        ] do
        %{height: height, block: mb, time: mb_time, txs: [tx_rec]} = blocks[:mb1]

        signed_tx = :aetx_sign.new(tx_rec, [])
        txi = @very_high_txi + 1
        block_index = {height, 0}

        txn_mutations =
          Transaction.transaction_mutations(
            signed_tx,
            txi,
            {block_index, mb, mb_time, %{}},
            false
          )

        Database.commit(txn_mutations)

        {sender_pk, recipient_pk} = pubkeys_from_tx(signed_tx)
        assert sender_pk == recipient_pk

        assert {:spend_tx, _pos, ^sender_pk, ^txi} =
                 query_spend_tx_field_index(sender_pk, @sender_id_pos)

        assert {:spend_tx, _pos, ^recipient_pk, ^txi} =
                 query_spend_tx_field_index(recipient_pk, @recipient_id_pos)
      end
    end
  end

  describe "transaction_mutations/4" do
    test "aex9 contract creation by a contract call" do
      signed_tx =
        {:signed_tx,
         {:aetx, :contract_call_tx, :aect_call_tx, 194,
          {:contract_call_tx,
           {:id, :account,
            <<87, 95, 129, 255, 176, 162, 151, 183, 114, 93, 198, 113, 218, 11, 23, 105, 177, 252,
              92, 190, 69, 56, 92, 123, 90, 209, 252, 46, 175, 29, 96, 157>>}, 41,
           {:id, :contract,
            <<10, 126, 159, 135, 82, 51, 128, 194, 144, 132, 41, 25, 103, 230, 4, 179, 77, 54, 3,
              118, 14, 88, 180, 200, 222, 12, 124, 138, 3, 39, 137, 110>>}, 3,
           183_880_000_000_000, 0, 0, 25_000, 1_000_000_000,
           <<43, 17, 173, 201, 32, 179, 75, 159, 2, 160, 83, 107, 86, 97, 199, 199, 69, 232, 131,
             106, 241, 190, 181, 55, 62, 215, 254, 27, 189, 54, 54, 3, 152, 10, 245, 52, 84, 143,
             225, 73, 60, 7, 159, 2, 160, 165, 183, 23, 114, 145, 239, 159, 199, 241, 17, 145, 38,
             165, 16, 97, 176, 78, 150, 205, 43, 175, 9, 38, 160, 18, 49, 212, 116, 169, 115, 144,
             97, 175, 130, 0, 1, 1, 27, 111, 130, 3, 168, 175, 130, 0, 1, 1, 27, 111, 134, 1, 124,
             235, 169, 148, 223>>, [],
           <<87, 95, 129, 255, 176, 162, 151, 183, 114, 93, 198, 113, 218, 11, 23, 105, 177, 252,
             92, 190, 69, 56, 92, 123, 90, 209, 252, 46, 175, 29, 96, 157>>}},
         [
           <<241, 150, 148, 131, 67, 46, 246, 13, 168, 16, 229, 204, 67, 231, 236, 95, 54, 170,
             101, 153, 197, 29, 208, 162, 209, 157, 206, 128, 150, 32, 89, 254, 40, 198, 80, 136,
             48, 195, 190, 146, 235, 50, 195, 54, 72, 37, 63, 86, 82, 78, 182, 119, 240, 223, 137,
             176, 53, 71, 171, 222, 74, 17, 102, 11>>
         ]}

      txi = 31_215_242
      block_index = {577_695, 6}

      block_hash =
        <<64, 198, 150, 216, 251, 176, 118, 72, 222, 152, 196, 47, 169, 57, 5, 18, 210, 58, 168,
          236, 180, 164, 35, 88, 244, 72, 40, 164, 117, 172, 212, 175>>

      mb_time = 1_648_465_667_388
      mb_events = %{}

      # setup contract
      contract_pk = setup_contract(signed_tx)
      aex9_meta_info = {"TestAEX9-B vs TestAEX9-A", "TAEX9-B/TAEX9-A", 18}

      with_mocks [
        {Contract, [],
         [
           is_aex9?: fn ct_pk -> ct_pk != contract_pk end,
           aex9_meta_info: fn ct_pk -> if ct_pk != contract_pk, do: {:ok, aex9_meta_info} end,
           call_tx_info: fn _tx, ^contract_pk, _block_hash, _to_map ->
             {
               fun_args_res("create_pair"),
               call_rec("create_pair")
             }
           end
         ]}
      ] do
        mutations =
          signed_tx
          |> Transaction.transaction_mutations(
            txi,
            {block_index, block_hash, mb_time, mb_events}
          )
          |> List.flatten()

        child_contract_pk = Validate.id!(fun_args_res("create_pair")[:result][:value])

        assert Enum.any?(mutations, fn
                 %Aex9CreateContractMutation{
                   aex9_meta_info: ^aex9_meta_info,
                   block_index: ^block_index,
                   contract_pk: ^child_contract_pk,
                   create_txi: ^txi
                 } ->
                   true

                 %{} ->
                   false
               end)
      end
    end
  end

  #
  # Helper functions
  #
  defp setup_contract(signed_tx) do
    {_mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    contract_pk = :aect_call_tx.contract_pubkey(tx)
    :ets.insert(:ct_create_sync_cache, {contract_pk, 31_215_229})

    functions =
      %{
        @create_pair_hash => "create_pair"
      }
      |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

    type_info = {:fcode, functions, nil, nil}
    AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

    contract_pk
  end

  defp pubkeys_from_tx(signed_tx) do
    {_mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    sender_pk = tx |> elem(@sender_id_pos) |> Validate.id!()
    recipient_pk = tx |> elem(@recipient_id_pos) |> Validate.id!()
    {sender_pk, recipient_pk}
  end

  defp query_spend_tx_field_index(pubkey, pos) do
    {:ok, index} = Database.prev_key(Model.Field, {:spend_tx, pos, pubkey, nil})
    index
  end
end
