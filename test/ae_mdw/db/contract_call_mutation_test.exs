defmodule AeMdw.Db.ContractCallMutationTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Sync.AsyncTasks.Consumer
  alias AeMdw.Validate

  import AeMdw.Node.ContractCallFixtures

  import Mock
  require Model

  @mint_ct_pk Validate.id!("ct_pqfbS94uUpE8reSwgtaAy5odGi7cPRMAxbjMyEzpTGqwTWyn5")

  @transfer_ct_pk Validate.id!("ct_pqfbS94uUpE8reSwgtaAy5odGi7cPRMAxbjMyEzpTGqwTWyn5")

  @transfer_allow_ct_pk Validate.id!("ct_2Jm3s7uHMvM7tRSCvFWurCh8LjZoTHa7LshKZSTZigCv1WnvmJ")

  @burn_ct_pk Validate.id!("ct_kraQeEEaoKKUq3qPHxyrsN1rvD9jPr58QFat5Ha641LtgLwEA")
  @burn_caller_pk <<234, 90, 164, 101, 3, 211, 169, 40, 246, 51, 6, 203, 132, 12, 34, 114, 203,
                    201, 104, 124, 76, 144, 134, 158, 55, 106, 213, 160, 170, 64, 59, 72>>

  describe "aex9 presence" do
    test "add aex9 presence after a mint" do
      call_txi = 10_552_888
      block_index = {kbi, mbi} = {246_949, 83}

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, @mint_ct_pk, 121})
        )
        |> State.new()

      assert {account_pk, mutation} =
               contract_call_mutation("mint", block_index, call_txi, @mint_ct_pk)

      contract_pk = @mint_ct_pk
      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      kb_hash = <<123_451::256>>
      next_mb_hash = Validate.id!("mh_2JWXTaf6BzWrTpZMMcBZjxUXX9zNDva2GBT71jhFNiV1ic1gsL")

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn _height ->
             kb_hash
           end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_mb_hash} ->
             balances = %{{:address, account_pk} => 100_000_000_000_000_001}

             {balances, nil}
           end
         ]}
      ] do
        state =
          state
          |> State.commit_mem([mutation])
          |> process_async_tasks()

        assert State.exists?(state, Model.Aex9AccountPresence, {account_pk, contract_pk})
      end
    end

    test "add aex9 presence after a transfer" do
      call_txi = 10_587_359
      block_index = {kbi, mbi} = {247_411, 5}

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, @transfer_ct_pk, 122})
        )
        |> State.new()

      assert {account_pk, mutation} =
               contract_call_mutation(
                 "transfer",
                 block_index,
                 call_txi,
                 @transfer_ct_pk
               )

      contract_pk = @transfer_ct_pk
      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation
      kb_hash = <<123_452::256>>
      next_mb_hash = Validate.id!("mh_2Kf3h4eYi77yvMg9HtLMLX9zJtThm6xBCbefCbKQpSi8Rxrcgy")

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn height ->
             assert ^height = kbi + 1
             kb_hash
           end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_mb_hash} ->
             balances = %{{:address, account_pk} => 100_000_000_000_000_002}

             {balances, nil}
           end
         ]}
      ] do
        state =
          state
          |> State.commit_mem([mutation])
          |> process_async_tasks()

        assert State.exists?(state, Model.Aex9AccountPresence, {account_pk, contract_pk})
      end
    end

    test "add aex9 presence after a transfer allowance" do
      call_txi = 11_440_639
      block_index = {kbi, mbi} = {258_867, 73}

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, @transfer_allow_ct_pk, 123})
        )
        |> State.new()

      assert {account_pk, mutation} =
               contract_call_mutation(
                 "transfer_allowance",
                 block_index,
                 call_txi,
                 @transfer_allow_ct_pk
               )

      contract_pk = @transfer_allow_ct_pk
      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      kb_hash = <<123_453::256>>
      next_mb_hash = Validate.id!("mh_2WR69dhBSJLc9gBt6gnHRJCYfCR7BjKNNQteDRshe5CNErghVR")

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn height ->
             assert ^height = kbi + 1
             kb_hash
           end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_mb_hash} ->
             balances = %{{:address, account_pk} => 100_000_000_000_000_003}

             {balances, nil}
           end
         ]}
      ] do
        state =
          state
          |> State.commit_mem([mutation])
          |> process_async_tasks()

        assert State.exists?(state, Model.Aex9AccountPresence, {account_pk, contract_pk})
      end
    end

    test "add aex9 presence after a burn (balance is 0)" do
      call_txi = 11_213_118
      block_index = {kbi, mbi} = {255_795, 74}

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, @burn_ct_pk, 124})
        )
        |> State.new()

      assert {account_pk, mutation} =
               contract_call_mutation("burn", block_index, call_txi, @burn_ct_pk)

      contract_pk = @burn_ct_pk
      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation
      kb_hash = <<123_454::256>>
      next_mb_hash = Validate.id!("mh_9943pc2nXD7BaJjZMwaAYd5Jk4DbPY3THDoh8Sfgy7nTyrZ41")

      with_mocks [
        {AeMdw.Node.Db, [],
         [
           get_key_block_hash: fn height ->
             assert ^height = kbi + 1
             kb_hash
           end,
           get_next_hash: fn ^kb_hash, ^mbi -> next_mb_hash end,
           aex9_balances: fn ^contract_pk, {:micro, ^kbi, ^next_mb_hash} ->
             balances = %{{:address, account_pk} => 0}

             {balances, nil}
           end
         ]}
      ] do
        state =
          state
          |> State.commit_mem([mutation])
          |> process_async_tasks()

        assert State.exists?(state, Model.Aex9AccountPresence, {account_pk, contract_pk})
      end
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

      state =
        NullStore.new()
        |> MemStore.new()
        |> Store.put(
          Model.Field,
          Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
        )
        |> State.new()

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
           aex9_balances: fn ^contract_pk, _next -> {%{}, nil} end
         ]}
      ] do
        state =
          state
          |> State.commit_mem([mutation])
          |> process_async_tasks()

        [{^contract_pk, [_transfer_evt_hash | [from_pk, to_pk, <<amount::256>>]], _data}] =
          :aect_call.log(call_rec)

        assert State.exists?(state, Model.Aex9Transfer, {from_pk, call_txi, to_pk, amount, 0})
        assert State.exists?(state, Model.RevAex9Transfer, {to_pk, call_txi, from_pk, amount, 0})
        assert State.exists?(state, Model.IdxAex9Transfer, {call_txi, 0, from_pk, to_pk, amount})
        assert State.exists?(state, Model.Aex9PairTransfer, {from_pk, to_pk, call_txi, amount, 0})
      end
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

  defp process_async_tasks(state) do
    state.jobs
    |> Enum.flat_map(fn {{job_type, dedup_args}, extra_args} ->
      Consumer.mutations(job_type, dedup_args ++ extra_args)
    end)
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(state, &Mutation.execute/2)
  end
end
