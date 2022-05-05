defmodule AeMdw.Aex141Test do
  use ExUnit.Case

  alias AeMdw.Aex141
  alias AeMdw.Database
  alias AeMdw.Db.Model

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1]

  require Model

  describe "fetch_token/1" do
    test "returns nft meta info" do
      contract_pk = <<14_112_345::256>>

      aex141_meta_info =
        {name, symbol, base_url, type} = {"AE Boots", "Boot", Faker.Internet.url(), :url}

      txi = 11_123_456

      m_aexn =
        Model.aexn_contract(
          index: {:aex141, contract_pk},
          txi: txi,
          meta_info: aex141_meta_info
        )

      Database.dirty_write(Model.AexnContract, m_aexn)

      contract_id = enc_ct(contract_pk)

      assert {:ok,
              %{
                name: ^name,
                symbol: ^symbol,
                base_url: ^base_url,
                create_txi: ^txi,
                contract_id: ^contract_id,
                metadata_type: ^type
              }} = Aex141.fetch_token(contract_pk)
    end
  end
end
