defmodule AeMdw.Db.Sync.ContractTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model

  alias AeMdw.Db.DatabaseWriteMutation
  alias AeMdw.Db.Sync.Contract
  alias AeMdw.Node

  import Mock

  require Model

  describe "events/3" do
    test "it creates an internal call for each event that's not Chain.create/clone" do
      create_txi = 1
      call_txi = 3

      account_id =
        <<44, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24,
          251, 165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>

      tx_1 = {:tx1, account_id}
      tx_2 = {:tx2, account_id}

      events = [
        {{:internal_call_tx, "some_funname_1"}, %{info: tx_1}},
        {{:internal_call_tx, "some_funname_2"}, %{info: tx_2}}
      ]

      mutation_1 =
        DatabaseWriteMutation.new(
          Model.IdIntContractCall,
          Model.id_int_contract_call(index: {account_id, 1, 3, 0})
        )

      mutation_2 =
        DatabaseWriteMutation.new(
          Model.IdIntContractCall,
          Model.id_int_contract_call(index: {account_id, 1, 3, 1})
        )

      with_mocks [
        {:aetx, [], [specialize_type: fn _tx -> {:spend_tx, tx_1} end]},
        {Node, [], [tx_ids: fn :spend_tx -> [{:sender_id, 1}] end]}
      ] do
        mutations = Contract.events_mutations(events, {0, 0}, <<>>, call_txi, <<>>, create_txi)

        assert mutation_1 in mutations
        assert mutation_2 in mutations
      end
    end

    test "it creates an Field record for each Chain.create/clone event, using the next Call.amount event" do
      create_txi = 1
      call_txi = 3

      contract_id =
        <<44, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24,
          251, 165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>

      tx_1 = {:tx1, contract_id}
      tx_2 = {:tx2, contract_id}

      events = [
        {{:internal_call_tx, "Chain.create"}, %{info: :error}},
        {{:internal_call_tx, "Call.amount"}, %{info: tx_1}},
        {{:internal_call_tx, "Chain.clone"}, %{info: :error}},
        {{:internal_call_tx, "Call.amount"}, %{info: tx_2}}
      ]

      mutation_1 =
        DatabaseWriteMutation.new(
          Model.FnameIntContractCall,
          Model.fname_int_contract_call(index: {"Call.amount", 3, 0})
        )

      mutation_2 =
        DatabaseWriteMutation.new(
          Model.FnameIntContractCall,
          Model.fname_int_contract_call(index: {"Call.amount", 3, 1})
        )

      with_mocks [
        {:aetx, [], [specialize_type: fn _tx -> {:spend_tx, tx_1} end]},
        {Node, [], [tx_ids: fn :spend_tx -> [{:sender_id, 1}] end]},
        {:aec_spend_tx, [], [recipient_id: fn _tx -> {:id, :account, contract_id} end]}
      ] do
        mutations = Contract.events_mutations(events, {0, 0}, <<>>, call_txi, <<>>, create_txi)

        assert mutation_1 in mutations
        assert mutation_2 in mutations
      end
    end
  end
end
