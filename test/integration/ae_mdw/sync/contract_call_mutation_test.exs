defmodule Integration.AeMdw.Db.ContractCallMutationTest do
  use ExUnit.Case

  @moduletag :integration

  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Validate

  import Support.TestMnesiaSandbox

  require Ex2ms
  require Model

  @aex9_ct_pk1 Validate.id!("ct_pqfbS94uUpE8reSwgtaAy5odGi7cPRMAxbjMyEzpTGqwTWyn5")
  @aex9_ct_pk2 Validate.id!("ct_2Jm3s7uHMvM7tRSCvFWurCh8LjZoTHa7LshKZSTZigCv1WnvmJ")

  test "add aex9 presence after a mint" do
    fn ->
      assert_presence("mint", @aex9_ct_pk1)

      :mnesia.abort(:rollback)
    end
    |> mnesia_sandbox()
  end

  test "add aex9 presence after a transfer" do
    fn ->
      assert_presence("transfer", @aex9_ct_pk1)

      :mnesia.abort(:rollback)
    end
    |> mnesia_sandbox()
  end

  test "add aex9 presence after a transfer allowance" do
    fn ->
      assert_presence("transfer_allowance", @aex9_ct_pk2)

      :mnesia.abort(:rollback)
    end
    |> mnesia_sandbox()
  end

  defp assert_presence(fname, contract_pk) do
    create_txi = Origin.tx_index({:contract, contract_pk})

    {[mint_args_res], _cont} =
      AeMdw.Db.Util.select(
        Model.ContractCall,
        Ex2ms.fun do
          {:contract_call, {^create_txi, call_txi}, ^fname, args, res, :_} ->
            {call_txi, args, res}
        end,
        1
      )

    {call_txi, args, res} = mint_args_res
    fun_arg_res = %{function: fname, arguments: args, result: res}

    account_pk =
      case args do
        [%{type: :address, value: account_pk}, _int_val] -> account_pk
        [%{type: :address}, %{type: :address, value: account_pk}, _int_val] -> account_pk
      end

    any_caller_pk = <<1::256>>

    mocked_call_rec =
      :aect_call.new(
        :aeser_id.create(:account, any_caller_pk),
        1,
        :aeser_id.create(:contract, contract_pk),
        1,
        1
      )

    DBContract.aex9_delete_presence(contract_pk, account_pk)

    contract_pk
    |> ContractCallMutation.new(any_caller_pk, create_txi, call_txi, fun_arg_res, mocked_call_rec)
    |> ContractCallMutation.mutate()

    assert {^account_pk, ^call_txi, ^contract_pk} =
             :mnesia.next(Model.Aex9AccountPresence, {account_pk, -1, nil})
  end
end
