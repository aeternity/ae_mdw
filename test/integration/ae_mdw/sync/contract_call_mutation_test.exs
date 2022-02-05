defmodule Integration.AeMdw.Db.ContractCallMutationTest do
  use ExUnit.Case

  @moduletag :integration

  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Contract
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Sync
  alias AeMdw.Db.Util
  alias AeMdw.Validate
  alias Support.AeMdw.Db.ContractTestUtil

  import Support.TestMnesiaSandbox

  require Ex2ms
  require Model

  # contract with mint and transfer on mainnet
  @aex9_ct_pk1 Validate.id!("ct_pqfbS94uUpE8reSwgtaAy5odGi7cPRMAxbjMyEzpTGqwTWyn5")
  # contract with transfer_allowance
  @aex9_ct_pk2 Validate.id!("ct_2Jm3s7uHMvM7tRSCvFWurCh8LjZoTHa7LshKZSTZigCv1WnvmJ")
  # contract with burn
  @aex9_ct_pk3 Validate.id!("ct_kraQeEEaoKKUq3qPHxyrsN1rvD9jPr58QFat5Ha641LtgLwEA")
  # aex9 created by contract call
  @aex9_ct_pk4 Validate.id!("ct_6MFUZmk8wE76qnQqEqitQztabxZrp8AhEiSSMuyQYeSWUU467")

  test "add aex9 presence after a mint" do
    fn ->
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
      ContractCallMutation.mutate(mutation)

      assert {^account_pk, ^call_txi, ^contract_pk} =
               :mnesia.next(Model.Aex9AccountPresence, {account_pk, -1, nil})

      :mnesia.abort(:rollback)
    end
    |> mnesia_sandbox()
  end

  test "add aex9 presence after a transfer" do
    fn ->
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
      ContractCallMutation.mutate(mutation)

      assert {^account_pk, ^call_txi, ^contract_pk} =
               :mnesia.next(Model.Aex9AccountPresence, {account_pk, -1, nil})

      :mnesia.abort(:rollback)
    end
    |> mnesia_sandbox()
  end

  test "add aex9 presence after a transfer allowance" do
    fn ->
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
      ContractCallMutation.mutate(mutation)

      assert {^account_pk, ^call_txi, ^contract_pk} =
               :mnesia.next(Model.Aex9AccountPresence, {account_pk, -1, nil})

      :mnesia.abort(:rollback)
    end
    |> mnesia_sandbox()
  end

  test "add aex9 presence after a burn (balance is 0)" do
    fn ->
      contract_pk = @aex9_ct_pk3
      call_txi = 11_213_118

      assert {account_pk,
              %ContractCallMutation{
                txi: ^call_txi,
                contract_pk: ^contract_pk
              }} = mutation = contract_call_mutation("burn", call_txi, @aex9_ct_pk3)

      # delete and create presence
      ContractTestUtil.aex9_delete_presence(contract_pk, account_pk)
      ContractCallMutation.mutate(mutation)

      assert {^account_pk, ^call_txi, ^contract_pk} =
               :mnesia.next(Model.Aex9AccountPresence, {account_pk, -1, nil})

      :mnesia.abort(:rollback)
    end
    |> mnesia_sandbox()
  end

  # credo:disable-for-next-line
  @tag (Application.get_env(:aecore, :network_id) != "ae_uat" && :skip) || :integration
  test "aex9 contract creation by a contract call" do
    fn ->
      txi = 25_729_031
      contract_pk = @aex9_ct_pk4
      tx_hash = Validate.id!("th_2c6Nipg2ijrpyS4UXWsE1Fd7t5cNtYJqYT3ecj3EAFgdtB1Gw9")
      {block_hash, :contract_call_tx, _signed_tx, tx} = NodeDb.get_tx_data(tx_hash)

      ^contract_pk = :aect_call_tx.contract_pubkey(tx)

      {fun_arg_res, call_rec} =
        Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)

      {child_mutations, aex9_meta_info} =
        Sync.Contract.child_contract_mutations(
          :aect_call.return_type(call_rec) == :ok,
          fun_arg_res,
          txi,
          tx_hash
        )

      child_contract_pk =
        <<115, 58, 92, 73, 111, 85, 214, 223, 85, 240, 254, 40, 105, 205, 139, 88, 161, 42, 130,
          241, 100, 162, 118, 163, 59, 130, 156, 123, 249, 57, 234, 13>>

      assert child_contract_pk != contract_pk

      assert ^child_mutations =
               Sync.Origin.origin_mutations(
                 :contract_call_tx,
                 nil,
                 child_contract_pk,
                 txi,
                 tx_hash
               )

      name = "TestAEX9-B vs TestAEX9-A"
      symbol = "TAEX9-B/TAEX9-A"
      decimals = 18
      assert {^name, ^symbol, ^decimals} = aex9_meta_info

      # delete if already synced
      :mnesia.delete(Model.Aex9Contract, {name, symbol, txi, decimals}, :write)
      :mnesia.delete(Model.Aex9ContractSymbol, {symbol, name, txi, decimals}, :write)
      :mnesia.delete(Model.RevAex9Contract, {txi, name, symbol, decimals}, :write)
      :mnesia.delete(Model.Aex9ContractPubkey, contract_pk, :write)

      call_mutation =
        ContractCallMutation.new(
          contract_pk,
          :aect_call_tx.caller_pubkey(tx),
          txi,
          txi,
          fun_arg_res,
          aex9_meta_info,
          call_rec
        )

      ContractCallMutation.mutate(call_mutation)

      m_contract = Model.aex9_contract(index: {name, symbol, txi, decimals})
      m_contract_sym = Model.aex9_contract_symbol(index: {symbol, name, txi, decimals})
      m_rev_contract = Model.rev_aex9_contract(index: {txi, name, symbol, decimals})
      m_contract_pk = Model.aex9_contract_pubkey(index: contract_pk, txi: txi)

      assert [^m_contract] =
               :mnesia.read(Model.Aex9Contract, {name, symbol, txi, decimals}, :write)

      assert [^m_contract_sym] =
               :mnesia.read(Model.Aex9ContractSymbol, {symbol, name, txi, decimals}, :write)

      assert [^m_rev_contract] =
               :mnesia.read(Model.RevAex9Contract, {txi, name, symbol, decimals}, :write)

      assert [^m_contract_pk] = :mnesia.read(Model.Aex9ContractPubkey, contract_pk, :write)

      :mnesia.abort(:rollback)
    end
    |> mnesia_sandbox()
  end

  defp contract_call_mutation(fname, contract_pk, call_txi, aex9_meta_info \\ nil) do
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
        aex9_meta_info,
        call_rec
      )

    {account_pk, mutation}
  end
end
