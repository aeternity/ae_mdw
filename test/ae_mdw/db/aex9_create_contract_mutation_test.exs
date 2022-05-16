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
      aex9_meta_info = {name, symbol, _decimals} = {"911058", "SPH", 18}
      block_index = {271_305, 99}
      create_txi = txi = 12_361_891

      Database.commit([
        Aex9CreateContractMutation.new(contract_pk, aex9_meta_info, block_index, create_txi)
      ])

      m_contract_pk =
        Model.aexn_contract(index: {:aex9, contract_pk}, txi: txi, meta_info: aex9_meta_info)

      assert {:ok, ^m_contract_pk} = Database.fetch(Model.AexnContract, {:aex9, contract_pk})
      assert Database.exists?(Model.AexnContractName, {:aex9, name, contract_pk})
      assert Database.exists?(Model.AexnContractSymbol, {:aex9, symbol, contract_pk})
    end
  end
end
