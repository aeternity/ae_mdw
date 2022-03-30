defmodule AeMdw.Db.ContractCallMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.Model
  alias AeMdw.Validate
  alias Support.AeMdw.Db.ContractTestUtil

  import AeMdw.Node.ContractCallFixtures

  require Ex2ms
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

  test "add aex9 presence after a mint" do
    call_txi = 10_552_888

    assert {account_pk, mutation} =
             contract_call_mutation("mint", call_txi, @mint_ct_pk, @mint_caller_pk)

    contract_pk = @mint_ct_pk
    assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

    # delete and create presence
    ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
    Database.commit([mutation])

    assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
             Database.next_key(Model.Aex9AccountPresence, {account_pk, -1, nil})
  end

  test "add aex9 presence after a transfer" do
    call_txi = 10_587_359

    assert {account_pk, mutation} =
             contract_call_mutation("transfer", call_txi, @transfer_ct_pk, @transfer_caller_pk)

    contract_pk = @transfer_ct_pk
    assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

    # delete and create presence
    ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
    Database.commit([mutation])

    assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
             Database.next_key(Model.Aex9AccountPresence, {account_pk, -1, nil})
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
    assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

    # delete and create presence
    ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
    Database.commit([mutation])

    assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
             Database.next_key(Model.Aex9AccountPresence, {account_pk, -1, nil})
  end

  test "add aex9 presence after a burn (balance is 0)" do
    call_txi = 11_213_118

    assert {account_pk, mutation} =
             contract_call_mutation("burn", call_txi, @burn_ct_pk, @burn_caller_pk)

    contract_pk = @burn_ct_pk
    assert %ContractCallMutation{txi: ^call_txi, contract_pk: ^contract_pk} = mutation

    # delete and create presence
    ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
    Database.commit([mutation])

    assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
             Database.next_key(Model.Aex9AccountPresence, {account_pk, -1, nil})
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
        caller_pk,
        call_txi - 1,
        call_txi,
        fun_arg_res,
        call_rec
      )

    {account_pk, mutation}
  end
end
