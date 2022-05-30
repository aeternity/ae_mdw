defmodule AeMdw.Db.AexnCreateContractMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.AexnCreateContractMutation
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
        AexnCreateContractMutation.new(
          :aex9,
          contract_pk,
          aex9_meta_info,
          block_index,
          create_txi
        )
      ])

      m_contract_pk =
        Model.aexn_contract(index: {:aex9, contract_pk}, txi: txi, meta_info: aex9_meta_info)

      assert {:ok, ^m_contract_pk} = Database.fetch(Model.AexnContract, {:aex9, contract_pk})
      assert Database.exists?(Model.AexnContractName, {:aex9, name, contract_pk})
      assert Database.exists?(Model.AexnContractSymbol, {:aex9, symbol, contract_pk})
    end

    test "successful for aex141 contract" do
      contract_pk = Validate.id!("ct_2ZpMr6PfL1XzgWosguyUtgr9b2kKeqqGQpwSeXzT28j7f8LJH5")

      aex141_meta_info =
        {name, symbol, _base_url, _type} = {"prenft2", "PNFT2", "some-fake-url", :url}

      block_index = {610_470, 77}
      create_txi = txi = 28_522_602

      Database.commit([
        AexnCreateContractMutation.new(
          :aex141,
          contract_pk,
          aex141_meta_info,
          block_index,
          create_txi
        )
      ])

      m_contract_pk =
        Model.aexn_contract(index: {:aex141, contract_pk}, txi: txi, meta_info: aex141_meta_info)

      assert {:ok, ^m_contract_pk} = Database.fetch(Model.AexnContract, {:aex141, contract_pk})
      assert Database.exists?(Model.AexnContractName, {:aex141, name, contract_pk})
      assert Database.exists?(Model.AexnContractSymbol, {:aex141, symbol, contract_pk})
    end
  end
end
