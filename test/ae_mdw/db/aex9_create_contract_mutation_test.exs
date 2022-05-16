defmodule AeMdw.Db.Aex9CreateContractMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Aex9CreateContractMutation
  alias AeMdw.Db.Model
  alias AeMdw.Validate

  require Model

  describe "execute" do
    test "successful for aex9 contract" do
      contract_pk = Validate.id!("ct_2TZsPKT5wyahqFrzp8YX7DfXQapQ4Qk65yn3sHbifU9Db9hoav")
      aex9_meta_info = {name, symbol, decimals} = {"911058", "SPH", 18}
      block_index = {271_305, 99}
      create_txi = txi = 12_361_891

      [Aex9CreateContractMutation.new(contract_pk, aex9_meta_info, block_index, create_txi)]
      |> Database.commit()

      m_contract = Model.aex9_contract(index: {name, symbol, txi, decimals})
      m_contract_sym = Model.aex9_contract_symbol(index: {symbol, name, txi, decimals})
      m_rev_contract = Model.rev_aex9_contract(index: {txi, name, symbol, decimals})
      m_contract_pk = Model.aexn_contract_pubkey(index: {:aex9, contract_pk}, txi: txi)

      assert {:ok, ^m_contract} =
               Database.fetch(Model.Aex9Contract, {name, symbol, txi, decimals})

      assert {:ok, ^m_contract_sym} =
               Database.fetch(Model.Aex9ContractSymbol, {symbol, name, txi, decimals})

      assert {:ok, ^m_rev_contract} =
               Database.fetch(Model.RevAex9Contract, {txi, name, symbol, decimals})

      assert {:ok, ^m_contract_pk} =
               Database.fetch(Model.AexNContractPubkey, {:aex9, contract_pk})
    end
  end
end
