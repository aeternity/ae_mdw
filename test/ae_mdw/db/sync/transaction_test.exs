defmodule AeMdw.Db.Sync.TransactionTest do
  use ExUnit.Case, async: false

  alias AeMdw.Node, as: AE

  alias AeMdw.AexnContracts
  alias AeMdw.Database
  alias AeMdw.Contract
  alias AeMdw.DryRun.Runner
  alias AeMdw.Db.AexnCreateContractMutation
  alias AeMdw.Db.Sync.Transaction
  alias AeMdw.Db.Model
  alias AeMdw.EtsCache
  alias AeMdw.Validate

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, spend_tx: 3]
  import AeMdw.Node.ContractCallFixtures
  import AeMdw.Node.AeTxFixtures
  import Mock

  require Model

  @sender_id_pos AE.tx_ids(:spend_tx).sender_id
  @recipient_id_pos AE.tx_ids(:spend_tx).recipient_id
  @very_high_txi 100_000_000_000
  @create_pair_hash <<38, 76, 208, 75>>
  @aex141_mint_signature %{
    <<207, 221, 154, 162>> => {[:address, {:variant, [tuple: [], tuple: [:string]]}], :integer}
  }

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
    test "creates aex9 contract on :contract_call_tx" do
      signed_tx = signed_tx(:contract_call_tx, :aex9_create)
      txi = 31_215_242
      block_index = {577_695, 6}
      block_hash = :crypto.strong_rand_bytes(32)
      mb_time = 1_648_465_667_388
      mb_events = %{}

      # setup contract
      contract_pk = setup_contract_on_call(signed_tx)
      aex9_meta_info = {"TestAEX9-B vs TestAEX9-A", "TAEX9-B/TAEX9-A", 18}
      child_contract_pk = Validate.id!(fun_args_res("create_pair")[:result][:value])

      with_mocks [
        {Contract, [],
         [
           call_tx_info: fn _tx, ^contract_pk, _block_hash ->
             {
               fun_args_res("create_pair"),
               call_rec("create_pair")
             }
           end
         ]},
        {AexnContracts, [],
         [
           is_aex9?: fn pk -> pk == child_contract_pk end,
           call_meta_info: fn _type, pk -> pk == child_contract_pk && {:ok, aex9_meta_info} end,
           call_extensions: fn _type, _pk -> {:ok, []} end
         ]}
      ] do
        mutations =
          signed_tx
          |> Transaction.transaction_mutations(
            txi,
            {block_index, block_hash, mb_time, mb_events}
          )
          |> List.flatten()

        assert Enum.any?(mutations, fn
                 %AexnCreateContractMutation{
                   aexn_type: :aex9,
                   aexn_meta_info: ^aex9_meta_info,
                   block_index: ^block_index,
                   contract_pk: ^child_contract_pk,
                   create_txi: ^txi,
                   extensions: []
                 } ->
                   true

                 %{} ->
                   false
               end)
      end
    end

    test "creates mintable aex141 contract on :contract_create_tx" do
      signed_tx = signed_tx(:contract_create_tx, :aex141)
      txi = 28_522_602
      block_index = {610_470, 77}
      block_hash = :crypto.strong_rand_bytes(32)
      mb_time = 1_653_918_598_237
      mb_events = %{}

      # setup contract
      contract_pk = setup_contract_on_create(signed_tx)
      number = abs(System.unique_integer())
      aex141_meta_info = {"test-nft#{number}", "test-nft#{number}", "http://some-fake-url", :url}

      with_mocks [
        {Contract, [],
         [
           is_contract?: fn ct_pk -> ct_pk == contract_pk end,
           get_init_call_rec: fn _tx, _hash ->
             {:call, <<1::256>>, {:id, :account, <<2::256>>}, 1, 123_456,
              {:id, :contract, contract_pk}, 1_000_000_000, 1_234, "?", :ok, []}
           end
         ]},
        {AexnContracts, [],
         [
           is_aex9?: fn _pk -> false end,
           call_meta_info: fn _type, pk -> pk == contract_pk && {:ok, aex141_meta_info} end,
           has_aex141_signatures?: fn pk -> pk == contract_pk end,
           call_extensions: fn :aex141, _pk -> {:ok, ["mintable"]} end,
           has_valid_aex141_extensions?: fn _extensions, _pk -> true end
         ]},
        {Runner, [],
         [
           call_contract: fn _pk, _hash, "extensions", [] -> {:ok, ["mintable"]} end
         ]}
      ] do
        mutations =
          signed_tx
          |> Transaction.transaction_mutations(
            txi,
            {block_index, block_hash, mb_time, mb_events}
          )
          |> List.flatten()

        assert Enum.any?(mutations, fn
                 %AexnCreateContractMutation{
                   aexn_type: :aex141,
                   aexn_meta_info: ^aex141_meta_info,
                   block_index: ^block_index,
                   contract_pk: ^contract_pk,
                   create_txi: ^txi,
                   extensions: ["mintable"]
                 } ->
                   true

                 %{} ->
                   false
               end)
      end
    end

    test "creates aex141 contract without error meta_info on :contract_create_tx" do
      signed_tx = signed_tx(:contract_create_tx, :aex141)
      txi = 28_522_603
      block_index = {610_470, 78}
      block_hash = :crypto.strong_rand_bytes(32)
      mb_time = 1_653_918_598_237
      mb_events = %{}

      # setup contract
      contract_pk = setup_contract_on_create(signed_tx)
      aex141_meta_info = {:error, :error, nil, nil}

      with_mocks [
        {Contract, [],
         [
           is_contract?: fn ct_pk -> ct_pk == contract_pk end,
           get_init_call_rec: fn _tx, _hash ->
             {:call, <<1::256>>, {:id, :account, <<2::256>>}, 1, 123_456,
              {:id, :contract, contract_pk}, 1_000_000_000, 1_234, "?", :ok, []}
           end
         ]},
        {AexnContracts, [],
         [
           is_aex9?: fn _pk -> false end,
           call_meta_info: fn _type, _pk -> {:ok, aex141_meta_info} end,
           has_aex141_signatures?: fn pk -> pk == contract_pk end,
           call_extensions: fn :aex141, _pk -> {:ok, ["mintable"]} end,
           has_valid_aex141_extensions?: fn _extensions, _pk -> true end
         ]},
        {Runner, [],
         [
           call_contract: fn _pk, _hash, "extensions", [] -> {:ok, ["mintable"]} end
         ]}
      ] do
        mutations =
          signed_tx
          |> Transaction.transaction_mutations(
            txi,
            {block_index, block_hash, mb_time, mb_events}
          )
          |> List.flatten()

        assert Enum.any?(mutations, fn
                 %AexnCreateContractMutation{
                   aexn_type: :aex141,
                   aexn_meta_info: ^aex141_meta_info,
                   block_index: ^block_index,
                   contract_pk: ^contract_pk,
                   create_txi: ^txi,
                   extensions: ["mintable"]
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
  defp setup_contract_on_call(signed_tx) do
    {_mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    contract_pk = :aect_call_tx.contract_pubkey(tx)

    functions =
      %{
        @create_pair_hash => "create_pair"
      }
      |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

    type_info = {:fcode, functions, nil, nil}
    EtsCache.put(Contract, contract_pk, {type_info, nil, nil})

    contract_pk
  end

  defp setup_contract_on_create(signed_tx) do
    {_mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
    contract_pk = :aect_create_tx.contract_pubkey(tx)

    functions =
      @aex141_mint_signature
      |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

    type_info = {:fcode, functions, nil, nil}
    EtsCache.put(Contract, contract_pk, {type_info, nil, nil})

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
