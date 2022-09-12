defmodule AeMdw.AexnTokensTest do
  use ExUnit.Case

  alias AeMdw.AexnTokens
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1]
  import AeMdwWeb.AexnView

  require Model

  describe "fetch_contract/1" do
    test "returns an AEX-9 contract meta info" do
      contract_pk = <<9_123_456::256>>
      aex9_meta_info = {name, symbol, decimals} = {"Token1", "TK1", 18}
      txi = 1_123_456_789
      extensions = ["ext1", "ext2"]
      state = State.new()

      m_aexn =
        Model.aexn_contract(
          index: {:aex9, contract_pk},
          txi: txi,
          meta_info: aex9_meta_info,
          extensions: extensions
        )

      Database.dirty_write(Model.AexnContract, m_aexn)

      contract_id = enc_ct(contract_pk)

      assert {:ok, m_aex9} = AexnTokens.fetch_contract(state, {:aex9, contract_pk})

      assert %{
               name: ^name,
               symbol: ^symbol,
               decimals: ^decimals,
               contract_txi: ^txi,
               contract_id: ^contract_id,
               extensions: ^extensions
             } = render_contract(state, m_aex9)
    end

    test "returns a AEX-141 contract meta info" do
      contract_pk = <<141_123_456::256>>

      aex141_meta_info =
        {name, symbol, base_url, type} = {"AE Boots", "Boot", "http://someurl.com", :url}

      txi = 2_123_456_789
      extensions = ["some-extension", "other-extension", "yet-another-extension"]
      state = State.new()

      m_aexn =
        Model.aexn_contract(
          index: {:aex141, contract_pk},
          txi: txi,
          meta_info: aex141_meta_info,
          extensions: extensions
        )

      Database.dirty_write(Model.AexnContract, m_aexn)

      contract_id = enc_ct(contract_pk)

      assert {:ok, m_aex141} = AexnTokens.fetch_contract(state, {:aex141, contract_pk})

      assert %{
               name: ^name,
               symbol: ^symbol,
               base_url: ^base_url,
               contract_txi: ^txi,
               contract_id: ^contract_id,
               metadata_type: ^type,
               extensions: ^extensions
             } = render_contract(state, m_aex141)
    end

    test "returns input error on AEX9 not found" do
      contract_id = "ct_KPfzobzyoPZjADKMWxDTbeZYfE9kSPpoJDbC6MkMztKtXJHRx"
      contract_pk = Validate.id!(contract_id)

      assert {:error, %ErrInput{reason: ErrInput.NotFound}} =
               AexnTokens.fetch_contract(State.new(), {:aex9, contract_pk})
    end

    test "returns input error AEX141 not found" do
      contract_id = "ct_KPfzobzyoPZjADKMWxDTbeZYfE9kSPpoJDbC6MkMztKtXJHRx"
      contract_pk = Validate.id!(contract_id)

      assert {:error, %ErrInput{reason: ErrInput.NotFound}} =
               AexnTokens.fetch_contract(State.new(), {:aex141, contract_pk})
    end
  end
end
