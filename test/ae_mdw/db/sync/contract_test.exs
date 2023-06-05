defmodule AeMdw.Db.Sync.ContractTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.Model

  alias AeMdw.AexnContracts
  alias AeMdw.Db.AexnCreateContractMutation
  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Db.Sync.Contract, as: SyncContract
  alias AeMdw.Db.Sync.Origin, as: SyncOrigin
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Db.OracleExtendMutation
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Validate

  import AeMdw.Node.ContractEventsFixtures
  import Mock

  require Model

  describe "events_mutations/4" do
    test "it creates an internal call for each event that's not Chain.create/clone" do
      call_txi = 3

      account_pk =
        <<44, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24,
          251, 165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>

      contract_pk =
        <<42, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24,
          251, 165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>

      {:ok, tx_1} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, account_pk),
          recipient_id: :aeser_id.create(:account, <<1::256>>),
          amount: 123,
          fee: 456,
          nonce: 1,
          payload: <<>>
        })

      {:ok, tx_2} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, account_pk),
          recipient_id: :aeser_id.create(:account, <<2::256>>),
          amount: 123,
          fee: 456,
          nonce: 2,
          payload: <<>>
        })

      events = [
        {{:internal_call_tx, "Call.amount"}, %{info: tx_1}},
        {{:internal_call_tx, "Call.amount"}, %{info: tx_2}}
      ]

      {tx_type1, tx_rec1} = :aetx.specialize_type(tx_1)
      {tx_type2, tx_rec2} = :aetx.specialize_type(tx_2)

      int_calls = [
        {0, "Call.amount", tx_type1, tx_1, tx_rec1},
        {1, "Call.amount", tx_type2, tx_2, tx_rec2}
      ]

      mutation = IntCallsMutation.new(contract_pk, call_txi, int_calls)
      mutations = SyncContract.events_mutations(events, {0, 0}, call_txi, <<>>, contract_pk)

      assert mutation in List.flatten(mutations)
    end

    test "it creates an Field record for each Chain.create/clone event, using the next Call.amount event" do
      call_txi = Enum.random(100_000..999_999)
      call_tx_hash = :crypto.strong_rand_bytes(32)

      contract_pk =
        <<44, 102, 253, 22, 212, 89, 216, 54, 106, 220, 2, 78, 65, 149, 128, 184, 42, 187, 24,
          251, 165, 15, 161, 139, 112, 108, 233, 167, 103, 44, 158, 24>>

      {:ok, tx_1} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, <<1::256>>),
          recipient_id: :aeser_id.create(:account, contract_pk),
          amount: 123,
          fee: 456,
          nonce: 1,
          payload: <<>>
        })

      {:ok, tx_2} =
        :aec_spend_tx.new(%{
          sender_id: :aeser_id.create(:account, <<2::256>>),
          recipient_id: :aeser_id.create(:account, contract_pk),
          amount: 123,
          fee: 456,
          nonce: 2,
          payload: <<>>
        })

      events = [
        {{:internal_call_tx, "Call.amount"}, %{info: tx_1}},
        {{:internal_call_tx, "Chain.create"}, %{info: :error}},
        {{:internal_call_tx, "Call.amount"}, %{info: tx_2}},
        {{:internal_call_tx, "Chain.clone"}, %{info: :error}}
      ]

      {tx_type1, tx_rec1} = :aetx.specialize_type(tx_1)
      {tx_type2, tx_rec2} = :aetx.specialize_type(tx_2)

      int_calls = [
        {0, "Call.amount", tx_type1, tx_1, tx_rec1},
        {1, "Call.amount", tx_type2, tx_2, tx_rec2}
      ]

      mutation = IntCallsMutation.new(contract_pk, call_txi, int_calls)

      contract_mutations =
        SyncOrigin.origin_mutations(
          :contract_call_tx,
          nil,
          contract_pk,
          call_txi,
          call_tx_hash
        )

      mutations =
        SyncContract.events_mutations(events, {0, 0}, call_txi, call_tx_hash, contract_pk)

      assert mutation in List.flatten(mutations)
      assert Enum.all?(contract_mutations, &(&1 in mutations))
    end

    test "create aex9 contract with Chain.clone" do
      aex9_contract_pk = Validate.id!("ct_2n7xLuQPWWw8Yj8yXPyrhZz3nucu2Cpjg7FxnoTmuVTgGAsUbJ")

      tx_events = [
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
         }},
        {{:internal_call_tx, "Chain.clone"},
         %{
           info: :error,
           tx_hash:
             <<50, 175, 183, 105, 50, 158, 138, 149, 125, 12, 47, 89, 117, 207, 2, 97, 50, 90,
               155, 225, 217, 103, 11, 202, 211, 247, 57, 189, 103, 224, 171, 230>>,
           type: :contract_call_tx
         }}
      ]

      with_mocks [
        {AexnContracts, [],
         [
           is_aex9?: fn ct_pk -> ct_pk == aex9_contract_pk end,
           call_meta_info: fn _type, ct_pk ->
             if ct_pk == aex9_contract_pk,
               do: {:ok, {"TestAEX9-A vs Wrapped Aeternity", "TAEX9-A/WAE", 18}}
           end,
           call_extensions: fn _type, _pk -> {:ok, []} end
         ]}
      ] do
        mutations =
          SyncContract.events_mutations(
            tx_events,
            {554_178, 13},
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
        |> SyncContract.events_mutations(block_index, call_txi, <<>>, -1)
        |> List.flatten()

      assert Enum.any?(event_mutations, fn
               %NameTransferMutation{
                 txi_idx: {^call_txi, 0},
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
        |> SyncContract.events_mutations(block_index, call_txi, <<>>, -1)
        |> List.flatten()

      assert Enum.any?(event_mutations, fn
               %NameUpdateMutation{
                 txi_idx: {^call_txi, 0},
                 block_index: ^block_index
               } ->
                 true

               %{} ->
                 false
             end)
    end

    test "register an oracle after Oracle.register putting its origin" do
      pubkey =
        <<128, 221, 110, 109, 56, 18, 16, 154, 47, 55, 243, 228, 66, 241, 214, 130, 244, 248, 135,
          231, 216, 113, 13, 248, 226, 63, 89, 50, 7, 22, 99, 187>>

      delta_ttl = 500

      {:ok, aetx} =
        :aeo_register_tx.new(%{
          account_id: :aeser_id.create(:account, pubkey),
          nonce: 1,
          abi_version: 1,
          query_format: "\"foo\"",
          response_format: "\"bar\"",
          query_fee: 100,
          oracle_ttl: {:delta, delta_ttl},
          fee: 10_000
        })

      sync_height = 50_000
      expire = sync_height + delta_ttl
      call_txi = sync_height * 1_000

      call_tx_hash = <<1::256>>
      contract_pk = <<2::256>>

      mutations =
        [{{:internal_call_tx, "Oracle.register"}, %{info: aetx}}]
        |> SyncContract.events_mutations(
          {sync_height, 0},
          call_txi,
          call_tx_hash,
          contract_pk
        )
        |> List.flatten()

      {_mod, tx} = :aetx.specialize_callback(aetx)
      tx_type = :oracle_register_tx

      assert [
               %IntCallsMutation{
                 call_txi: ^call_txi,
                 contract_pk: ^contract_pk,
                 int_calls: [{0, "Oracle.register", ^tx_type, ^aetx, ^tx}]
               },
               %WriteMutation{
                 table: Model.Origin,
                 record: Model.origin(index: {^tx_type, ^pubkey, ^call_txi})
               },
               %WriteMutation{
                 table: Model.RevOrigin,
                 record: Model.rev_origin(index: {^call_txi, ^tx_type, ^pubkey})
               },
               %AeMdw.Db.WriteFieldMutation{
                 pos: nil,
                 pubkey: ^pubkey,
                 tx_type: ^tx_type,
                 txi: ^call_txi
               },
               %OracleRegisterMutation{oracle_pk: ^pubkey, expire: ^expire}
             ] = mutations
    end

    test "extend an oracle after Oracle.extend" do
      pubkey =
        <<129, 221, 110, 109, 56, 18, 16, 154, 47, 55, 243, 228, 66, 241, 214, 130, 244, 248, 135,
          231, 216, 113, 13, 248, 226, 63, 89, 50, 7, 22, 99, 187>>

      delta_ttl = 500

      {:ok, aetx} =
        :aeo_extend_tx.new(%{
          oracle_id: :aeser_id.create(:oracle, pubkey),
          nonce: 2,
          oracle_ttl: {:delta, delta_ttl},
          fee: 5_000
        })

      sync_height = 50_000
      block_index = {sync_height, 0}
      call_txi = sync_height * 1_000
      call_tx_hash = <<2::256>>
      contract_pk = <<3::256>>

      mutations =
        [{{:internal_call_tx, "Oracle.extend"}, %{info: aetx}}]
        |> SyncContract.events_mutations(
          block_index,
          call_txi,
          call_tx_hash,
          contract_pk
        )
        |> List.flatten()

      {_mod, tx} = :aetx.specialize_callback(aetx)

      assert(
        [
          %IntCallsMutation{
            call_txi: ^call_txi,
            contract_pk: ^contract_pk,
            int_calls: [{0, "Oracle.extend", :oracle_extend_tx, ^aetx, ^tx}]
          },
          %OracleExtendMutation{
            oracle_pk: ^pubkey,
            block_index: ^block_index,
            txi_idx: {^call_txi, 0},
            delta_ttl: ^delta_ttl
          }
        ] = mutations
      )
    end
  end
end
