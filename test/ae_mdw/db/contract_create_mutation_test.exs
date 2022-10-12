defmodule AeMdw.Db.ContractCreateMutationTest do
  use ExUnit.Case, async: false

  import AeMdw.Node.ContractCallFixtures
  import Mock

  alias AeMdw.AsyncTaskTestUtil
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
          [],
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
            ContractCreateMutation.new(block_index, create_txi1, call_rec1),
            SyncContract.aexn_create_contract_mutation(contract_pk, block_index, create_txi1),
            Origin.origin_mutations(
              :contract_create_tx,
              nil,
              contract_pk,
              create_txi1,
              :crypto.strong_rand_bytes(32)
            )
          ])

        assert AsyncTaskTestUtil.list_pending()
               |> Enum.find(fn Model.async_task(args: args, extra_args: extra_args) ->
                 args == [contract_pk] and extra_args == [block_index, create_txi1]
               end)

        assert 1 == State.get_stat(state1, :contracts_created, 0)
        assert {:ok, create_txi1} == State.cache_get(state1, :ct_create_sync_cache, contract_pk)
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
        {:call, <<1::256>>, {:id, :account, <<2::256>>}, 1, height, {:id, :contract, contract_pk},
         1_000_000_000, 10_500, "?", :ok,
         [
           {contract_pk, [AeMdw.Node.aexn_mint_event_hash(), to_pk1, <<token_id1::256>>], ""},
           {contract_pk, [AeMdw.Node.aexn_mint_event_hash(), to_pk2, <<token_id2::256>>], ""},
           {contract_pk, [AeMdw.Node.aexn_mint_event_hash(), to_pk2, <<token_id3::256>>], ""}
         ]}

      with_mocks [
        {Contract, [],
         [
           is_contract?: fn ct_pk -> ct_pk == contract_pk end,
           get_init_call_rec: fn _tx, _hash -> call_rec end
         ]},
        {AexnContracts, [],
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
            ContractCreateMutation.new(block_index, create_txi, call_rec)
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
  end
end
