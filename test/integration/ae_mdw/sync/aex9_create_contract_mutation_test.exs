defmodule Integration.AeMdw.Db.Aex9CreateContractMutationTest do
  use ExUnit.Case

  @moduletag :integration

  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Contract
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync
  alias AeMdw.Validate

  require Ex2ms
  require Model

  # aex9 created by contract call
  @aex9_ct_pk Validate.id!("ct_6MFUZmk8wE76qnQqEqitQztabxZrp8AhEiSSMuyQYeSWUU467")

  # credo:disable-for-next-line
  @tag (Application.get_env(:aecore, :network_id) != "ae_uat" && :skip) || :integration
  test "aex9 contract creation by a contract call" do
    txi = 25_729_031
    contract_pk = @aex9_ct_pk
    tx_hash = Validate.id!("th_2c6Nipg2ijrpyS4UXWsE1Fd7t5cNtYJqYT3ecj3EAFgdtB1Gw9")
    {block_hash, :contract_call_tx, _signed_tx, tx} = NodeDb.get_tx_data(tx_hash)

    <<caller_pk::binary-32>> = :aect_call_tx.caller_pubkey(tx)
    ^contract_pk = :aect_call_tx.contract_pubkey(tx)

    {fun_arg_res, _call_rec} =
      Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)

    child_mutations =
      Sync.Contract.child_contract_mutations(
        fun_arg_res,
        caller_pk,
        {485_061, 76},
        txi,
        tx_hash
      )

    assert [aex9_child_contract_mutation | origin_mutations] = child_mutations
    assert child_contract_pk = aex9_child_contract_mutation.contract_pk
    assert child_contract_pk != contract_pk
    assert aex9_meta_info = aex9_child_contract_mutation.aex9_meta_info

    name = "TestAEX9-B vs TestAEX9-A"
    symbol = "TAEX9-B/TAEX9-A"
    decimals = 18
    assert {^name, ^symbol, ^decimals} = aex9_meta_info

    assert ^origin_mutations =
             Sync.Origin.origin_mutations(
               :contract_call_tx,
               nil,
               child_contract_pk,
               txi,
               tx_hash
             )

    # delete if already synced
    Database.dirty_delete(Model.Aex9Contract, {name, symbol, txi, decimals})
    Database.dirty_delete(Model.Aex9ContractSymbol, {symbol, name, txi, decimals})
    Database.dirty_delete(Model.RevAex9Contract, {txi, name, symbol, decimals})
    Database.dirty_delete(Model.Aex9ContractPubkey, child_contract_pk)

    Database.commit(child_mutations)

    m_contract = Model.aex9_contract(index: {name, symbol, txi, decimals})
    m_contract_sym = Model.aex9_contract_symbol(index: {symbol, name, txi, decimals})
    m_rev_contract = Model.rev_aex9_contract(index: {txi, name, symbol, decimals})
    m_contract_pk = Model.aex9_contract_pubkey(index: child_contract_pk, txi: txi)

    assert [^m_contract] = Database.read(Model.Aex9Contract, {name, symbol, txi, decimals})

    assert [^m_contract_sym] =
             Database.read(Model.Aex9ContractSymbol, {symbol, name, txi, decimals})

    assert [^m_rev_contract] = Database.read(Model.RevAex9Contract, {txi, name, symbol, decimals})

    assert [^m_contract_pk] = Database.read(Model.Aex9ContractPubkey, child_contract_pk)
  end
end
