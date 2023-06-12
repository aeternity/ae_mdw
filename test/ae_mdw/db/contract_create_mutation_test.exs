defmodule AeMdw.Db.ContractCreateMutationTest do
  use AeMdw.Db.MutationCase, async: false

  import AeMdw.Node.AexnEventFixtures, only: [aexn_event_hash: 1]
  import AeMdw.Node.ContractCallFixtures
  import Mock

  alias AeMdw.AexnContracts
  alias AeMdw.Contract
  alias AeMdw.Db.ContractCreateMutation
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Contract, as: SyncContract
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.DryRun.Runner
  alias AeMdw.Stats

  require Model

  describe "execute" do
    test "creates contract having aex9 log" do
      contract_pk = :crypto.strong_rand_bytes(32)
      meta_info = {"aex9t", "AEX9t", 18}

      with_mocks [
        {
          AexnContracts,
          [:passthrough],
          [
            is_aex9?: fn ct_pk -> ct_pk == contract_pk end,
            call_meta_info: fn _type, ct_pk -> ct_pk == contract_pk && {:ok, meta_info} end,
            call_extensions: fn _type, _pk -> {:ok, []} end
          ]
        }
      ] do
        {height, _mbi} = block_index = {492_393, 0}
        create_txi1 = 21_608_343
        call_rec1 = call_rec("transfer", contract_pk, height, contract_pk)

        state1 =
          NullStore.new()
          |> MemStore.new()
          |> State.new()
          |> State.commit_mem([
            ContractCreateMutation.new(create_txi1, call_rec1),
            SyncContract.aexn_create_contract_mutation(contract_pk, block_index, create_txi1),
            Origin.origin_mutations(
              :contract_create_tx,
              nil,
              contract_pk,
              create_txi1,
              :crypto.strong_rand_bytes(32)
            )
          ])

        assert 1 == State.get_stat(state1, :contracts_created, 0)
        assert {:ok, ^create_txi1} = State.cache_get(state1, :ct_create_sync_cache, contract_pk)
      end
    end

    test "creates contract having aex9 balances" do
      contract_pk = :crypto.strong_rand_bytes(32)
      account_pk1 = :crypto.strong_rand_bytes(32)
      account_pk2 = :crypto.strong_rand_bytes(32)
      amount1 = Enum.random(1_000_000..9_999_999)
      amount2 = Enum.random(1_000_000..9_999_999)

      meta_info = {"aex9t", "AEX9t", 18}
      {height, mbi} = block_index = {492_393, 0}
      next_height = height + 1
      kb_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {
          AexnContracts,
          [:passthrough],
          [
            is_aex9?: fn ct_pk -> ct_pk == contract_pk end,
            call_meta_info: fn _type, ct_pk -> ct_pk == contract_pk && {:ok, meta_info} end,
            call_extensions: fn _type, _pk -> {:ok, []} end
          ]
        },
        {AeMdw.Node.Db, [:passthrough],
         [
           get_key_block_hash: fn ^next_height -> kb_hash end,
           get_next_hash: fn ^kb_hash, ^mbi -> <<1::256>> end,
           aex9_balances: fn ^contract_pk, {:micro, ^height, <<1::256>>} ->
             {:ok,
              %{
                {:address, account_pk1} => amount1,
                {:address, account_pk2} => amount2
              }}
           end
         ]}
      ] do
        create_txi = 21_608_343

        call_rec =
          call_rec("logs", contract_pk, height, nil, [
            {
              contract_pk,
              [<<123::256>>, <<456::256>>, <<789::256>>],
              ""
            }
          ])

        state =
          NullStore.new()
          |> MemStore.new()
          |> State.new()
          |> State.commit_mem([
            ContractCreateMutation.new(create_txi, call_rec),
            SyncContract.aexn_create_contract_mutation(contract_pk, block_index, create_txi),
            Origin.origin_mutations(
              :contract_create_tx,
              nil,
              contract_pk,
              create_txi,
              :crypto.strong_rand_bytes(32)
            )
          ])

        m_balance1 =
          Model.aex9_event_balance(
            index: {contract_pk, account_pk1},
            amount: amount1,
            txi: create_txi
          )

        m_balance2 =
          Model.aex9_event_balance(
            index: {contract_pk, account_pk2},
            amount: amount2,
            txi: create_txi
          )

        assert 1 == State.get_stat(state, :contracts_created, 0)
        assert {:ok, ^create_txi} = State.cache_get(state, :ct_create_sync_cache, contract_pk)

        assert {:ok, ^m_balance1} =
                 State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk1})

        assert {:ok, ^m_balance2} =
                 State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk2})
      end
    end

    test "add nfts ownerships after mint logs" do
      contract_pk = :crypto.strong_rand_bytes(32)
      to_pk1 = :crypto.strong_rand_bytes(32)
      to_pk2 = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      block_index = {height, 1}
      create_txi = Enum.random(10_000_000..99_999_999)
      token_id1 = Enum.random(1_000..10_000)
      token_id2 = Enum.random(10_001..20_000)
      token_id3 = Enum.random(20_001..30_000)

      call_rec =
        :aect_call.new(
          :aeser_id.create(:account, <<2::256>>),
          1,
          :aeser_id.create(:contract, contract_pk),
          height,
          1_000_000_000
        )

      call_rec =
        :aect_call.set_log(
          [
            {contract_pk, [aexn_event_hash(:mint), to_pk1, <<token_id1::256>>], ""},
            {contract_pk, [aexn_event_hash(:mint), to_pk2, <<token_id2::256>>], ""},
            {contract_pk, [aexn_event_hash(:mint), to_pk2, <<token_id3::256>>], ""}
          ],
          call_rec
        )

      with_mocks [
        {Contract, [],
         [
           is_contract?: fn ct_pk -> ct_pk == contract_pk end,
           get_init_call_rec: fn _tx, _hash -> call_rec end
         ]},
        {AexnContracts, [:passthrough],
         [
           is_aex9?: fn _pk -> false end,
           call_meta_info: fn _type, ^contract_pk ->
             {:ok, {"test1", "TEST1", "http://some-fake-url", :url}}
           end,
           has_aex141_signatures?: fn _height, pk -> pk == contract_pk end,
           call_extensions: fn :aex141, _pk -> {:ok, ["mintable"]} end,
           has_valid_aex141_extensions?: fn _extensions, ^contract_pk -> true end
         ]},
        {Runner, [],
         [
           call_contract: fn ^contract_pk, _hash, "extensions", [] -> {:ok, ["mintable"]} end
         ]}
      ] do
        state =
          NullStore.new()
          |> MemStore.new()
          |> State.new()
          |> State.commit_mem([
            SyncContract.aexn_create_contract_mutation(contract_pk, block_index, create_txi),
            Origin.origin_mutations(
              :contract_create_tx,
              nil,
              contract_pk,
              create_txi,
              :crypto.strong_rand_bytes(32)
            ),
            ContractCreateMutation.new(create_txi, call_rec)
          ])

        assert State.exists?(state, Model.NftOwnership, {to_pk1, contract_pk, token_id1})
        assert State.exists?(state, Model.NftOwnership, {to_pk2, contract_pk, token_id2})
        assert State.exists?(state, Model.NftOwnership, {to_pk2, contract_pk, token_id3})

        assert {:ok, Model.stat(payload: 3)} =
                 State.get(state, Model.Stat, Stats.nfts_count_key(contract_pk))

        assert {:ok, Model.stat(payload: 2)} =
                 State.get(state, Model.Stat, Stats.nft_owners_count_key(contract_pk))

        assert {:ok, Model.nft_token_owner(owner: ^to_pk1)} =
                 State.get(state, Model.NftTokenOwner, {contract_pk, token_id1})

        assert {:ok, Model.nft_token_owner(owner: ^to_pk2)} =
                 State.get(state, Model.NftTokenOwner, {contract_pk, token_id2})

        assert {:ok, Model.nft_token_owner(owner: ^to_pk2)} =
                 State.get(state, Model.NftTokenOwner, {contract_pk, token_id3})

        assert State.exists?(state, Model.NftOwnerToken, {contract_pk, to_pk1, token_id1})
        assert State.exists?(state, Model.NftOwnerToken, {contract_pk, to_pk2, token_id2})
        assert State.exists?(state, Model.NftOwnerToken, {contract_pk, to_pk2, token_id3})
      end
    end

    test "inits token limit", %{store: store} do
      contract_pk = :crypto.strong_rand_bytes(32)
      token_limit = Enum.random(1_000..9_999)
      height = Enum.random(100_000..999_999)
      create_txi = Enum.random(10_000_000..99_999_999)
      extensions = ["mintable_limit"]

      valid_event = {
        contract_pk,
        [
          aexn_event_hash(:token_limit),
          <<token_limit::256>>
        ],
        ""
      }

      invalid_event = {
        contract_pk,
        [
          aexn_event_hash(:token_limit),
          <<token_limit + 1::256>>,
          <<token_limit + 2::256>>
        ],
        ""
      }

      call_rec = call_rec("logs", contract_pk, height, nil, [valid_event, invalid_event])

      with_mocks [
        {Contract, [:passthrough],
         [
           is_contract?: fn ^contract_pk -> true end,
           get_init_call_rec: fn _tx, _hash -> call_rec end
         ]},
        {AexnContracts, [:passthrough],
         [
           is_aex9?: fn ^contract_pk -> false end,
           call_meta_info: fn _type, ^contract_pk ->
             {:ok, {"test1", "TEST1", "http://some-fake-url", :url}}
           end,
           has_aex141_signatures?: fn _height, ^contract_pk -> true end,
           call_extensions: fn :aex141, _pk -> {:ok, extensions} end,
           has_valid_aex141_extensions?: fn _extensions, ^contract_pk -> true end
         ]},
        {Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "extensions", [] -> {:ok, extensions} end
         ]}
      ] do
        mutations = [
          SyncContract.aexn_create_contract_mutation(contract_pk, {height, 0}, create_txi),
          Origin.origin_mutations(
            :contract_create_tx,
            nil,
            contract_pk,
            create_txi,
            :crypto.strong_rand_bytes(32)
          ),
          ContractCreateMutation.new(create_txi, call_rec)
        ]

        store = change_store(store, [mutations])

        assert {:ok, Model.aexn_contract(extensions: ^extensions)} =
                 Store.get(store, Model.AexnContract, {:aex141, contract_pk})

        assert {:ok,
                Model.nft_contract_limits(token_limit: ^token_limit, txi: ^create_txi, log_idx: 0)} =
                 Store.get(store, Model.NftContractLimits, contract_pk)
      end
    end

    test "inits template limit", %{store: store} do
      contract_pk = :crypto.strong_rand_bytes(32)
      template_limit = Enum.random(100..999)
      height = Enum.random(100_000..999_999)
      create_txi = Enum.random(10_000_000..99_999_999)
      extensions = ["mintable_template_limit"]

      valid_event = {
        contract_pk,
        [
          aexn_event_hash(:template_limit),
          <<template_limit::256>>
        ],
        ""
      }

      invalid_event = {
        contract_pk,
        [
          aexn_event_hash(:template_limit),
          <<template_limit + 1::256>>,
          <<template_limit + 2::256>>
        ],
        ""
      }

      call_rec = call_rec("logs", contract_pk, height, nil, [valid_event, invalid_event])

      with_mocks [
        {Contract, [:passthrough],
         [
           is_contract?: fn ^contract_pk -> true end,
           get_init_call_rec: fn _tx, _hash -> call_rec end
         ]},
        {AexnContracts, [:passthrough],
         [
           is_aex9?: fn ^contract_pk -> false end,
           call_meta_info: fn _type, ^contract_pk ->
             {:ok, {"test1", "TEST1", "http://some-fake-url", :url}}
           end,
           has_aex141_signatures?: fn _height, ^contract_pk -> true end,
           call_extensions: fn :aex141, _pk -> {:ok, extensions} end,
           has_valid_aex141_extensions?: fn _extensions, ^contract_pk -> true end
         ]},
        {Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "extensions", [] -> {:ok, extensions} end
         ]}
      ] do
        mutations = [
          SyncContract.aexn_create_contract_mutation(contract_pk, {height, 0}, create_txi),
          Origin.origin_mutations(
            :contract_create_tx,
            nil,
            contract_pk,
            create_txi,
            :crypto.strong_rand_bytes(32)
          ),
          ContractCreateMutation.new(create_txi, call_rec)
        ]

        store = change_store(store, [mutations])

        assert {:ok, Model.aexn_contract(extensions: ^extensions)} =
                 Store.get(store, Model.AexnContract, {:aex141, contract_pk})

        assert {:ok,
                Model.nft_contract_limits(
                  template_limit: ^template_limit,
                  txi: ^create_txi,
                  log_idx: 0
                )} = Store.get(store, Model.NftContractLimits, contract_pk)
      end
    end
  end
end
