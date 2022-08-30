defmodule AeMdw.Db.ContractCallMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.AsyncTaskTestUtil
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Validate

  import AeMdw.Node.ContractCallFixtures
  import AeMdwWeb.Helpers.AexnHelper, only: [enc_id: 1]

  import Mock
  require Model

  @burn_caller_pk <<234, 90, 164, 101, 3, 211, 169, 40, 246, 51, 6, 203, 132, 12, 34, 114, 203,
                    201, 104, 124, 76, 144, 134, 158, 55, 106, 213, 160, 170, 64, 59, 72>>

  describe "aex9 presence" do
    test "add aex9 presence after a mint" do
      call_txi = 10_552_888
      block_index = {246_949, 83}
      contract_pk = :crypto.strong_rand_bytes(32)

      assert {account_pk, mutation} =
               contract_call_mutation("mint", block_index, call_txi, contract_pk)

      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      NullStore.new()
      |> MemStore.new()
      |> State.new()
      |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
      |> State.commit_mem([mutation])

      assert AsyncTaskTestUtil.list_pending()
             |> Enum.find(fn Model.async_task(args: args, extra_args: extra_args) ->
               args == [contract_pk] and extra_args == [block_index, call_txi]
             end)
    end

    test "add aex9 presence after a transfer" do
      call_txi = 10_587_359
      block_index = {247_411, 5}
      contract_pk = :crypto.strong_rand_bytes(32)

      assert {account_pk, mutation} =
               contract_call_mutation(
                 "transfer",
                 block_index,
                 call_txi,
                 contract_pk
               )

      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      NullStore.new()
      |> MemStore.new()
      |> State.new()
      |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
      |> State.commit_mem([mutation])

      assert AsyncTaskTestUtil.list_pending()
             |> Enum.find(fn Model.async_task(args: args, extra_args: extra_args) ->
               args == [contract_pk] and extra_args == [block_index, call_txi]
             end)
    end

    test "add aex9 presence after a transfer allowance" do
      call_txi = 11_440_639
      block_index = {258_867, 73}
      contract_pk = :crypto.strong_rand_bytes(32)

      assert {_account_pk, mutation} =
               contract_call_mutation(
                 "transfer_allowance",
                 block_index,
                 call_txi,
                 contract_pk
               )

      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      NullStore.new()
      |> MemStore.new()
      |> State.new()
      |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
      |> State.commit_mem([mutation])

      assert AsyncTaskTestUtil.list_pending()
             |> Enum.find(fn Model.async_task(args: args, extra_args: extra_args) ->
               args == [contract_pk] and extra_args == [block_index, call_txi]
             end)
    end

    test "add aex9 presence after a burn (balance is 0)" do
      call_txi = 11_213_118
      block_index = {255_795, 74}
      contract_pk = :crypto.strong_rand_bytes(32)

      assert {account_pk, mutation} =
               contract_call_mutation("burn", block_index, call_txi, contract_pk)

      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      NullStore.new()
      |> MemStore.new()
      |> State.new()
      |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
      |> State.commit_mem([mutation])

      assert AsyncTaskTestUtil.list_pending()
             |> Enum.find(fn Model.async_task(args: args, extra_args: extra_args) ->
               args == [contract_pk] and extra_args == [block_index, call_txi]
             end)
    end
  end

  describe "aex9 transfer" do
    test "add aex9 transfers after a call with transfer logs" do
      kb_hash = <<123_453::256>>
      next_mb_hash = Validate.id!("mh_9943pc2nXD7BaJjZMwaAYd5Jk4DbPY3THDoh8Sfgy7nTyrZ41")

      contract_pk =
        <<45, 195, 148, 17, 5, 88, 182, 202, 65, 160, 150, 218, 33, 163, 136, 171, 149, 101, 165,
          178, 212, 56, 89, 23, 172, 233, 200, 126, 138, 235, 158, 11>>

      call_txi = 9_353_623

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: "ak_2UqKYBBgVWfBeFYdn5sBS75B1cfLMPFSCy95xQoRo9SKNvvLgb"
          },
          %{type: :int, value: 1000}
        ],
        function: "transfer",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        {:call,
         <<61, 34, 73, 220, 196, 10, 139, 58, 161, 170, 48, 233, 27, 228, 57, 151, 209, 214, 234,
           100, 208, 116, 7, 9, 47, 146, 57, 178, 38, 46, 228, 66>>,
         {:id, :account,
          <<86, 184, 235, 22, 134, 71, 254, 125, 140, 211, 113, 59, 82, 110, 159, 107, 223, 171,
            122, 119, 157, 71, 130, 57, 92, 34, 139, 37, 241, 226, 10, 119>>}, 2726, 231_734,
         {:id, :contract,
          <<45, 195, 148, 17, 5, 88, 182, 202, 65, 160, 150, 218, 33, 163, 136, 171, 149, 101,
            165, 178, 212, 56, 89, 23, 172, 233, 200, 126, 138, 235, 158, 11>>}, 1_000_000_000,
         3576, "?", :ok,
         [
           {<<45, 195, 148, 17, 5, 88, 182, 202, 65, 160, 150, 218, 33, 163, 136, 171, 149, 101,
              165, 178, 212, 56, 89, 23, 172, 233, 200, 126, 138, 235, 158, 11>>,
            [
              <<34, 60, 57, 226, 157, 255, 100, 103, 254, 221, 160, 151, 88, 217, 23, 129, 197,
                55, 46, 9, 31, 248, 107, 58, 249, 227, 16, 227, 134, 86, 43, 239>>,
              <<86, 184, 235, 22, 134, 71, 254, 125, 140, 211, 113, 59, 82, 110, 159, 107, 223,
                171, 122, 119, 157, 71, 130, 57, 92, 34, 139, 37, 241, 226, 10, 119>>,
              <<194, 229, 0, 254, 146, 22, 182, 30, 138, 228, 107, 198, 46, 64, 230, 179, 99, 174,
                235, 166, 26, 232, 91, 34, 203, 153, 74, 213, 27, 190, 6, 88>>,
              <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 3, 232>>
            ], ""}
         ]}

      mutation =
        ContractCallMutation.new(
          contract_pk,
          {231_734, 54},
          call_txi,
          fun_arg_res,
          call_rec
        )

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn 231_735 -> kb_hash end,
           get_next_hash: fn ^kb_hash, 54 -> next_mb_hash end,
           aex9_balances: fn ^contract_pk, _next -> {:ok, %{}} end
         ]}
      ] do
        state =
          NullStore.new()
          |> MemStore.new()
          |> State.new()
          |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
          |> State.commit_mem([mutation])

        [{^contract_pk, [_transfer_evt_hash | [from_pk, to_pk, <<amount::256>>]], _data}] =
          :aect_call.log(call_rec)

        assert State.exists?(state, Model.Aex9Transfer, {from_pk, call_txi, to_pk, amount, 0})
        assert State.exists?(state, Model.RevAex9Transfer, {to_pk, call_txi, from_pk, amount, 0})
        assert State.exists?(state, Model.IdxAex9Transfer, {call_txi, 0, from_pk, to_pk, amount})
        assert State.exists?(state, Model.Aex9PairTransfer, {from_pk, to_pk, call_txi, amount, 0})
      end
    end
  end

  describe "aex141 transfer" do
    test "add aex141 transfers after a call with transfer logs" do
      contract_pk = :crypto.strong_rand_bytes(32)
      from_pk = :crypto.strong_rand_bytes(32)
      to_pk = :crypto.strong_rand_bytes(32)
      height = Enum.random(100_000..999_999)
      call_txi = Enum.random(10_000_000..99_999_999)
      token_id = Enum.random(1..100_000)

      fun_arg_res = %{
        arguments: [
          %{
            type: :address,
            value: enc_id(from_pk)
          },
          %{
            type: :address,
            value: enc_id(to_pk)
          },
          %{type: :int, value: token_id}
        ],
        function: "transfer",
        result: %{type: :unit, value: ""}
      }

      call_rec =
        {:call, :crypto.strong_rand_bytes(32), {:id, :account, :crypto.strong_rand_bytes(32)}, 1,
         height, {:id, :contract, contract_pk}, 1_000_000_000, 42_000, "?", :ok,
         [
           {contract_pk,
            [AeMdw.Node.aexn_transfer_event_hash(), from_pk, to_pk, <<token_id::256>>], ""}
         ]}

      mutation =
        ContractCallMutation.new(
          contract_pk,
          {height, 0},
          call_txi,
          fun_arg_res,
          call_rec
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> State.put(Model.AexnContract, Model.aexn_contract(index: {:aex141, contract_pk}))
        |> State.put(
          Model.AexnContract,
          Model.nft_ownership(index: {from_pk, contract_pk, token_id})
        )
        |> State.cache_put(:ct_create_sync_cache, contract_pk, call_txi - 1)
        |> State.commit_mem([mutation])

      assert State.exists?(state, Model.NftOwnership, {to_pk, contract_pk, token_id})
      refute State.exists?(state, Model.NftOwnership, {from_pk, contract_pk, token_id})
    end
  end

  defp contract_call_mutation(fname, block_index, call_txi, contract_pk) do
    %{arguments: args} = fun_arg_res = fun_args_res(fname)
    call_rec = call_rec(fname)

    account_pk =
      if fname in ["burn"] do
        @burn_caller_pk
      else
        case args do
          [%{type: :address, value: account_id}, _int_val] ->
            Validate.id!(account_id)

          [%{type: :address}, %{type: :address, value: account_id}, _int_val] ->
            Validate.id!(account_id)
        end
      end

    functions =
      AeMdw.Node.aex9_signatures()
      |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

    type_info = {:fcode, functions, nil, nil}
    AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

    mutation =
      ContractCallMutation.new(
        contract_pk,
        block_index,
        call_txi,
        fun_arg_res,
        call_rec
      )

    {account_pk, mutation}
  end
end
