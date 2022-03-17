defmodule Integration.AeMdw.Db.ContractCallMutationTest do
  use ExUnit.Case

  @moduletag :integration

  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Contract
  alias AeMdw.Database
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Util
  alias AeMdw.Validate
  alias Support.AeMdw.Db.ContractTestUtil

  require Ex2ms
  require Model

  # contract with mint and transfer on mainnet
  @aex9_ct_pk1 Validate.id!("ct_pqfbS94uUpE8reSwgtaAy5odGi7cPRMAxbjMyEzpTGqwTWyn5")
  # contract with transfer_allowance
  @aex9_ct_pk2 Validate.id!("ct_2Jm3s7uHMvM7tRSCvFWurCh8LjZoTHa7LshKZSTZigCv1WnvmJ")
  # contract with burn
  @aex9_ct_pk3 Validate.id!("ct_kraQeEEaoKKUq3qPHxyrsN1rvD9jPr58QFat5Ha641LtgLwEA")

  test "add aex9 presence after a mint" do
    contract_pk = @aex9_ct_pk1
    # mint
    call_txi = 10_552_888

    assert {account_pk,
            %ContractCallMutation{
              txi: ^call_txi,
              contract_pk: ^contract_pk
            }} = mutation = contract_call_mutation("mint", call_txi, @aex9_ct_pk1)

    # delete and create presence
    ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
    Database.commit([mutation])

    assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
             Database.next_key(Model.Aex9AccountPresence, {account_pk, -1, nil})
  end

  test "add aex9 presence after a transfer" do
    contract_pk = @aex9_ct_pk1
    # transfer
    call_txi = 10_587_359

    assert {account_pk,
            %ContractCallMutation{
              txi: ^call_txi,
              contract_pk: ^contract_pk
            }} = mutation = contract_call_mutation("transfer", call_txi, @aex9_ct_pk1)

    # delete and create presence
    ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
    Database.commit([mutation])

    assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
             Database.next_key(Model.Aex9AccountPresence, {account_pk, -1, nil})
  end

  test "add aex9 presence after a transfer allowance" do
    contract_pk = @aex9_ct_pk2
    # transfer_allowance
    call_txi = 11_440_639

    assert {account_pk,
            %ContractCallMutation{
              txi: ^call_txi,
              contract_pk: ^contract_pk
            }} = mutation = contract_call_mutation("transfer_allowance", call_txi, @aex9_ct_pk2)

    # delete and create presence
    ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
    Database.commit([mutation])

    assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
             Database.next_key(Model.Aex9AccountPresence, {account_pk, -1, nil})
  end

  test "add aex9 presence after a burn (balance is 0)" do
    contract_pk = @aex9_ct_pk3
    call_txi = 11_213_118

    assert {account_pk,
            %ContractCallMutation{
              txi: ^call_txi,
              contract_pk: ^contract_pk
            }} = mutation = contract_call_mutation("burn", call_txi, @aex9_ct_pk3)

    # delete and create presence
    ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
    Database.commit([mutation])

    assert {:ok, {^account_pk, ^call_txi, ^contract_pk}} =
             Database.next_key(Model.Aex9AccountPresence, {account_pk, -1, nil})
  end

  defp contract_call_mutation(fname, call_txi, contract_pk) do
    Model.tx(id: tx_hash) = Util.read_tx!(call_txi)
    {block_hash, :contract_call_tx, _signed_tx, tx} = NodeDb.get_tx_data(tx_hash)
    ^contract_pk = :aect_call_tx.contract_pubkey(tx)

    {%{arguments: args} = fun_arg_res, call_rec} =
      Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)

    <<caller_pk::binary-32>> = :aect_call_tx.caller_pubkey(tx)

    account_pk =
      if fname in ["burn", "swap"] do
        caller_pk
      else
        case args do
          [%{type: :address, value: account_pk}, _int_val] -> account_pk
          [%{type: :address}, %{type: :address, value: account_pk}, _int_val] -> account_pk
        end
      end

    mutation =
      ContractCallMutation.new(
        contract_pk,
        caller_pk,
        Origin.tx_index!({:contract, contract_pk}),
        call_txi,
        fun_arg_res,
        call_rec
      )

    {account_pk, mutation}
  end
end
