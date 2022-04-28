defmodule AeMdw.Db.ContractCallMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.Model
  alias AeMdw.Validate
  alias Support.AeMdw.Db.ContractTestUtil

  import AeMdw.Node.ContractCallFixtures

  # import Mock
  require Model

  @mint_ct_pk Validate.id!("ct_pqfbS94uUpE8reSwgtaAy5odGi7cPRMAxbjMyEzpTGqwTWyn5")
  @mint_caller_pk <<177, 109, 71, 150, 121, 127, 54, 94, 201, 60, 70, 245, 34, 29, 197, 129, 184,
                    20, 45, 115, 96, 123, 219, 39, 172, 49, 54, 12, 180, 88, 204, 248>>

  @transfer_ct_pk Validate.id!("ct_pqfbS94uUpE8reSwgtaAy5odGi7cPRMAxbjMyEzpTGqwTWyn5")
  @transfer_caller_pk <<25, 28, 236, 151, 15, 221, 20, 64, 110, 174, 115, 50, 53, 233, 214, 119,
                        44, 124, 66, 251, 47, 138, 163, 2, 69, 171, 46, 248, 46, 154, 37, 51>>

  @transfer_allow_ct_pk Validate.id!("ct_2Jm3s7uHMvM7tRSCvFWurCh8LjZoTHa7LshKZSTZigCv1WnvmJ")
  @transfer_allow_caller_pk <<117, 28, 32, 5, 40, 93, 216, 179, 224, 57, 208, 77, 88, 86, 168,
                              136, 223, 91, 24, 79, 252, 100, 141, 144, 124, 117, 91, 41, 115,
                              208, 244, 74>>

  @burn_ct_pk Validate.id!("ct_kraQeEEaoKKUq3qPHxyrsN1rvD9jPr58QFat5Ha641LtgLwEA")
  @burn_caller_pk <<234, 90, 164, 101, 3, 211, 169, 40, 246, 51, 6, 203, 132, 12, 34, 114, 203,
                    201, 104, 124, 76, 144, 134, 158, 55, 106, 213, 160, 170, 64, 59, 72>>

  describe "aex9 presence" do
    test "add aex9 presence after a mint" do
      call_txi = 10_552_888

      assert {account_pk, mutation} =
               contract_call_mutation("mint", call_txi, @mint_ct_pk, @mint_caller_pk)

      contract_pk = @mint_ct_pk
      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      # delete and create presence
      ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)

      Database.dirty_write(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, @mint_ct_pk, 123})
      )

      Database.commit([mutation])

      # delete and create presence
      ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
      Database.commit([mutation])

      assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
               Database.next_key(Model.Aex9AccountPresence, {account_pk, call_txi, nil})
    end

    test "add aex9 presence after a transfer" do
      call_txi = 10_587_359

      assert {account_pk, mutation} =
               contract_call_mutation("transfer", call_txi, @transfer_ct_pk, @transfer_caller_pk)

      contract_pk = @transfer_ct_pk

      Database.dirty_write(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, @transfer_ct_pk, 123})
      )

      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      # delete and create presence
      ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
      Database.commit([mutation])

      assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
               Database.next_key(Model.Aex9AccountPresence, {account_pk, call_txi, nil})
    end

    test "add aex9 presence after a transfer allowance" do
      call_txi = 11_440_639

      assert {account_pk, mutation} =
               contract_call_mutation(
                 "transfer_allowance",
                 call_txi,
                 @transfer_allow_ct_pk,
                 @transfer_allow_caller_pk
               )

      contract_pk = @transfer_allow_ct_pk

      Database.dirty_write(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, @transfer_allow_ct_pk, 123})
      )

      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      # delete and create presence
      ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
      Database.commit([mutation])

      assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
               Database.next_key(Model.Aex9AccountPresence, {account_pk, call_txi, nil})
    end

    test "add aex9 presence after a burn (balance is 0)" do
      call_txi = 11_213_118

      assert {account_pk, mutation} =
               contract_call_mutation("burn", call_txi, @burn_ct_pk, @burn_caller_pk)

      contract_pk = @burn_ct_pk

      Database.dirty_write(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, @burn_ct_pk, 123})
      )

      assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

      # delete and create presence
      ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
      Database.commit([mutation])

      assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
               Database.next_key(Model.Aex9AccountPresence, {account_pk, call_txi, nil})
    end
  end

  describe "aex9 transfer" do
    test "add aex9 transfers after a call with transfer logs" do
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

      Database.dirty_write(
        Model.Field,
        Model.field(index: {:contract_create_tx, nil, contract_pk, call_txi - 1})
      )

      functions =
        AeMdw.Node.aex9_signatures()
        |> Enum.into(%{}, fn {hash, type} -> {hash, {nil, type, nil}} end)

      type_info = {:fcode, functions, nil, nil}
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      Database.commit([mutation])

      [{^contract_pk, [_transfer_evt_hash | [from_pk, to_pk, <<amount::256>>]], _data}] =
        :aect_call.log(call_rec)

      assert Database.exists?(Model.Aex9Transfer, {from_pk, call_txi, to_pk, amount, 0})
      assert Database.exists?(Model.RevAex9Transfer, {to_pk, call_txi, from_pk, amount, 0})
      assert Database.exists?(Model.IdxAex9Transfer, {call_txi, 0, from_pk, to_pk, amount})
      assert Database.exists?(Model.Aex9PairTransfer, {from_pk, to_pk, call_txi, amount, 0})
    end
  end

  defp contract_call_mutation(fname, call_txi, contract_pk, caller_pk) do
    %{arguments: args} = fun_arg_res = fun_args_res(fname)
    call_rec = call_rec(fname)

    account_pk =
      if fname in ["burn", "swap"] do
        caller_pk
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
        {240_000, 12},
        call_txi,
        fun_arg_res,
        call_rec
      )

    {account_pk, mutation}
  end
end
