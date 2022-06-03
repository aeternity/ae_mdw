defmodule AeMdw.Db.Sync.ContractTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model

  alias AeMdw.Contracts.AexnContract
  alias AeMdw.Db.AexnCreateContractMutation
  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Db.Sync.Contract, as: SyncContract
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Node
  alias AeMdw.Validate

  import AeMdw.Node.ContractEventsFixtures
  import Mock

  require Model

  describe "events_mutations/4" do
    test "it creates an internal call for each event that's not Chain.create/clone" do
      call_txi = 3

      account_id =
        <<44, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24,
          251, 165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>

      contract_pk =
        <<42, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24,
          251, 165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>

      tx_1 = {:tx1, account_id}
      tx_2 = {:tx2, account_id}

      events = [
        {{:internal_call_tx, "some_funname_1"}, %{info: tx_1}},
        {{:internal_call_tx, "some_funname_2"}, %{info: tx_2}}
      ]

      int_calls = [
        {"some_funname_1", :spend_tx, tx_1, tx_1},
        {"some_funname_2", :spend_tx, tx_2, tx_1}
      ]

      mutation = IntCallsMutation.new(contract_pk, call_txi, int_calls)

      with_mocks [
        {:aetx, [], [specialize_type: fn _tx -> {:spend_tx, tx_1} end]},
        {Node, [], [tx_ids: fn :spend_tx -> [{:sender_id, 1}] end]}
      ] do
        mutations =
          SyncContract.events_mutations(events, {0, 0}, <<>>, call_txi, <<>>, contract_pk)

        assert mutation in List.flatten(mutations)
      end
    end

    test "it creates an Field record for each Chain.create/clone event, using the next Call.amount event" do
      call_txi = 3

      contract_pk =
        <<44, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24,
          251, 165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>

      tx_1 = {:tx1, contract_pk}
      tx_2 = {:tx2, contract_pk}

      events = [
        {{:internal_call_tx, "Chain.create"}, %{info: :error}},
        {{:internal_call_tx, "Call.amount"}, %{info: tx_1}},
        {{:internal_call_tx, "Chain.clone"}, %{info: :error}},
        {{:internal_call_tx, "Call.amount"}, %{info: tx_2}}
      ]

      int_calls = [
        {"Call.amount", :spend_tx, tx_1, tx_1},
        {"Call.amount", :spend_tx, tx_2, tx_1}
      ]

      mutation = IntCallsMutation.new(contract_pk, call_txi, int_calls)

      with_mocks [
        {:aetx, [], [specialize_type: fn _tx -> {:spend_tx, tx_1} end]},
        {Node, [], [tx_ids: fn :spend_tx -> [{:sender_id, 1}] end]},
        {:aec_spend_tx, [], [recipient_id: fn _tx -> {:id, :account, contract_pk} end]}
      ] do
        mutations =
          SyncContract.events_mutations(events, {0, 0}, <<>>, call_txi, <<>>, contract_pk)

        assert mutation in List.flatten(mutations)
      end
    end

    test "create aex9 contract with Chain.clone" do
      aex9_contract_pk = Validate.id!("ct_2n7xLuQPWWw8Yj8yXPyrhZz3nucu2Cpjg7FxnoTmuVTgGAsUbJ")

      tx_events = [
        {{:internal_call_tx, "Chain.clone"},
         %{
           info: :error,
           tx_hash:
             <<50, 175, 183, 105, 50, 158, 138, 149, 125, 12, 47, 89, 117, 207, 2, 97, 50, 90,
               155, 225, 217, 103, 11, 202, 211, 247, 57, 189, 103, 224, 171, 230>>,
           type: :contract_call_tx
         }},
        {{:internal_call_tx, "Call.amount"},
         %{
           info:
             {:aetx, :spend_tx, :aec_spend_tx, 88,
              {:spend_tx,
               {:id, :account,
                <<119, 188, 109, 120, 250, 56, 247, 180, 131, 241, 75, 129, 38, 118, 119, 224,
                  142, 113, 227, 78, 233, 147, 100, 188, 163, 26, 145, 253, 121, 183, 62, 80>>},
               {:id, :account, aex9_contract_pk}, 0, 0, 0, 0, "Call.amount"}},
           tx_hash:
             <<50, 175, 183, 105, 50, 158, 138, 149, 125, 12, 47, 89, 117, 207, 2, 97, 50, 90,
               155, 225, 217, 103, 11, 202, 211, 247, 57, 189, 103, 224, 171, 230>>,
           type: :contract_call_tx
         }}
      ]

      with_mocks [
        {AexnContract, [],
         [
           is_aex9?: fn ct_pk -> ct_pk == aex9_contract_pk end,
           call_meta_info: fn ct_pk ->
             if ct_pk == aex9_contract_pk,
               do: {:ok, {"TestAEX9-A vs Wrapped Aeternity", "TAEX9-A/WAE", 18}}
           end
         ]}
      ] do
        mutations =
          SyncContract.events_mutations(
            tx_events,
            {554_178, 13},
            <<1::256>>,
            25_866_736,
            <<2::256>>,
            25_866_736
          )

        assert mutations
               |> List.flatten()
               |> Enum.any?(fn
                 %AexnCreateContractMutation{} -> true
                 _other -> false
               end)
      end
    end

    test "creates name transfer mutation" do
      block_index = {262_167, 0}
      call_txi = 11_684_918

      event_mutations =
        "AENS.transfer"
        |> contract_events()
        |> SyncContract.events_mutations(block_index, <<>>, call_txi, <<>>, -1)
        |> List.flatten()

      assert Enum.any?(event_mutations, fn
               %NameTransferMutation{
                 txi: ^call_txi,
                 block_index: ^block_index
               } ->
                 true

               %{} ->
                 false
             end)
    end

    test "creates name update mutation" do
      block_index = {443_440, 0}
      call_txi = 23_198_023

      event_mutations =
        "AENS.update"
        |> contract_events()
        |> SyncContract.events_mutations(block_index, <<>>, call_txi, <<>>, -1)
        |> List.flatten()

      assert Enum.any?(event_mutations, fn
               %NameUpdateMutation{
                 txi: ^call_txi,
                 block_index: ^block_index
               } ->
                 true

               %{} ->
                 false
             end)
    end
  end
end
