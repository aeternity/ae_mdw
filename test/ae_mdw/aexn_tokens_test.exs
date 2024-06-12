defmodule AeMdw.AexnTokensTest do
  use ExUnit.Case

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.AexnTokens
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate

  import AeMdw.Util.Encoding, only: [encode_contract: 1]
  import AeMdw.TestUtil, only: [empty_state: 0]

  require Model

  describe "fetch_contract/1" do
    test "returns an AEX-9 contract meta info" do
      contract_pk = <<9_123_456::256>>
      aex9_meta_info = {name, symbol, decimals} = {"Token1", "TK1", 18}
      txi = 1_123_456_789
      decoded_tx_hash = <<txi::256>>
      tx_hash = Enc.encode(:tx_hash, decoded_tx_hash)
      extensions = ["ext1", "ext2"]
      state = State.new()

      m_aexn =
        Model.aexn_contract(
          index: {:aex9, contract_pk},
          txi_idx: {txi, -1},
          meta_info: aex9_meta_info,
          extensions: extensions
        )

      m_tx = Model.tx(index: txi, id: decoded_tx_hash)

      state =
        state
        |> State.put(Model.AexnContract, m_aexn)
        |> State.put(Model.Tx, m_tx)

      contract_id = encode_contract(contract_pk)

      assert {:ok, aex9_contract} = AexnTokens.fetch_contract(state, :aex9, contract_pk, true)

      assert %{
               name: ^name,
               symbol: ^symbol,
               decimals: ^decimals,
               contract_tx_hash: ^tx_hash,
               contract_id: ^contract_id,
               extensions: ^extensions
             } = aex9_contract
    end

    test "returns a AEX-141 contract meta info" do
      contract_pk = <<141_123_456::256>>

      aex141_meta_info =
        {name, symbol, base_url, type} = {"AE Boots", "Boot", "http://someurl.com", :url}

      txi = 2_123_456_789
      decoded_tx_hash = <<txi::256>>
      tx_hash = Enc.encode(:tx_hash, decoded_tx_hash)

      extensions = ["some-extension", "other-extension", "yet-another-extension"]
      state = State.new()

      m_aexn =
        Model.aexn_contract(
          index: {:aex141, contract_pk},
          txi_idx: {txi, -1},
          meta_info: aex141_meta_info,
          extensions: extensions
        )

      m_tx = Model.tx(index: txi, id: decoded_tx_hash)

      Database.dirty_write(Model.AexnContract, m_aexn)
      Database.dirty_write(Model.Tx, m_tx)

      contract_id = encode_contract(contract_pk)

      assert {:ok, aex141_contract} = AexnTokens.fetch_contract(state, :aex141, contract_pk, true)

      assert %{
               name: ^name,
               symbol: ^symbol,
               base_url: ^base_url,
               contract_tx_hash: ^tx_hash,
               contract_id: ^contract_id,
               metadata_type: ^type,
               extensions: ^extensions
             } = aex141_contract
    end

    test "returns input error on AEX9 not found" do
      contract_id = "ct_KPfzobzyoPZjADKMWxDTbeZYfE9kSPpoJDbC6MkMztKtXJHRx"
      contract_pk = Validate.id!(contract_id)

      assert {:error, %ErrInput{reason: ErrInput.NotFound}} =
               AexnTokens.fetch_contract(State.new(), :aex9, contract_pk, false)
    end

    test "returns input error AEX141 not found" do
      contract_id = "ct_KPfzobzyoPZjADKMWxDTbeZYfE9kSPpoJDbC6MkMztKtXJHRx"
      contract_pk = Validate.id!(contract_id)

      assert {:error, %ErrInput{reason: ErrInput.NotFound}} =
               AexnTokens.fetch_contract(State.new(), :aex141, contract_pk, false)
    end
  end

  describe "fetch_contracts/1" do
    test "returns AEX-9 contracts sorted by creation" do
      contract_pk1 = <<2::256>>
      contract_pk2 = <<1::256>>
      txi1 = 123_456_788
      txi2 = 123_456_789

      m1 =
        Model.aexn_contract(
          index: {:aex9, contract_pk1},
          txi_idx: {txi1, -1},
          meta_info: {"TokenB1", "TKB1", 18},
          extensions: ["extB1"]
        )

      m2 =
        Model.aexn_contract(
          index: {:aex9, contract_pk2},
          txi_idx: {txi2, -1},
          meta_info: {"TokenA1", "TKA1", 18},
          extensions: ["extA1"]
        )

      state =
        empty_state()
        |> State.put(Model.AexnContract, m1)
        |> State.put(Model.AexnContract, m2)
        |> State.put(
          Model.AexnContractCreation,
          Model.aexn_contract_creation(index: {:aex9, {txi1, -1}}, contract_pk: contract_pk1)
        )
        |> State.put(
          Model.AexnContractCreation,
          Model.aexn_contract_creation(index: {:aex9, {txi2, -1}}, contract_pk: contract_pk2)
        )
        |> State.put(
          Model.AexnContractName,
          Model.aexn_contract_name(index: {:aex9, "TokenB1", contract_pk1})
        )
        |> State.put(
          Model.AexnContractName,
          Model.aexn_contract_name(index: {:aex9, "TokenA1", contract_pk2})
        )

      pagination = {:forward, false, 10, false}

      assert {:ok, {nil, [contract1, contract2], nil}} =
               AexnTokens.fetch_contracts(state, pagination, :aex9, %{}, :name, nil, false)

      assert %{
               contract_id: "ct_11111111111111111111111111111118qjnEr",
               contract_txi: 123_456_789,
               decimals: 18,
               event_supply: 0,
               extensions: ["extA1"],
               holders: 0,
               initial_supply: 0,
               invalid: false,
               logs_count: 0,
               name: "TokenA1",
               symbol: "TKA1"
             } = contract1

      assert %{
               contract_id: "ct_1111111111111111111111111111111Hrt6FG",
               contract_txi: 123_456_788,
               decimals: 18,
               event_supply: 0,
               extensions: ["extB1"],
               holders: 0,
               initial_supply: 0,
               invalid: false,
               logs_count: 0,
               name: "TokenB1",
               symbol: "TKB1"
             } = contract2
    end

    test "returns AEX-141 contracts sorted by creation" do
      contract_pk1 = <<2::256>>
      contract_pk2 = <<1::256>>
      txi1 = 123_456_788
      txi2 = 123_456_789

      m1 =
        Model.aexn_contract(
          index: {:aex141, contract_pk1},
          txi_idx: {txi1, -1},
          meta_info: {"TokenB1", "TKB1", "", :url},
          extensions: ["extB1"]
        )

      m2 =
        Model.aexn_contract(
          index: {:aex141, contract_pk2},
          txi_idx: {txi2, -1},
          meta_info: {"TokenA1", "TKA1", "", :url},
          extensions: ["extA1"]
        )

      state =
        empty_state()
        |> State.put(Model.AexnContract, m1)
        |> State.put(Model.AexnContract, m2)
        |> State.put(
          Model.AexnContractCreation,
          Model.aexn_contract_creation(index: {:aex141, {txi1, -1}}, contract_pk: contract_pk1)
        )
        |> State.put(
          Model.AexnContractCreation,
          Model.aexn_contract_creation(index: {:aex141, {txi2, -1}}, contract_pk: contract_pk2)
        )
        |> State.put(
          Model.AexnContractName,
          Model.aexn_contract_name(index: {:aex141, "TokenB1", contract_pk1})
        )
        |> State.put(
          Model.AexnContractName,
          Model.aexn_contract_name(index: {:aex141, "TokenA1", contract_pk2})
        )
        |> State.put(Model.Tx, Model.tx(index: txi1, id: <<1::256>>))
        |> State.put(Model.Tx, Model.tx(index: txi2, id: <<2::256>>))

      pagination = {:forward, false, 10, false}

      assert {:ok, {nil, [contract2, contract1], nil}} =
               AexnTokens.fetch_contracts(state, pagination, :aex141, %{}, :name, nil, false)

      assert %{
               base_url: "",
               contract_id: "ct_1111111111111111111111111111111Hrt6FG",
               contract_txi: 123_456_788,
               extensions: ["extB1"],
               invalid: false,
               limits: nil,
               metadata_type: :url,
               name: "TokenB1",
               nft_owners: 0,
               nfts_amount: 0,
               symbol: "TKB1"
             } = contract1

      assert %{
               base_url: "",
               contract_id: "ct_11111111111111111111111111111118qjnEr",
               contract_txi: 123_456_789,
               extensions: ["extA1"],
               invalid: false,
               limits: nil,
               metadata_type: :url,
               name: "TokenA1",
               nft_owners: 0,
               nfts_amount: 0,
               symbol: "TKA1"
             } = contract2

      assert {:ok, {nil, [contract1, _contract2], nil}} =
               AexnTokens.fetch_contracts(state, pagination, :aex141, %{}, :creation, nil, true)

      assert %{
               base_url: "",
               contract_id: "ct_1111111111111111111111111111111Hrt6FG",
               contract_tx_hash: "th_11111111111111111111111111111118qjnEr",
               extensions: ["extB1"],
               invalid: false,
               limits: nil,
               metadata_type: :url,
               name: "TokenB1",
               nft_owners: 0,
               nfts_amount: 0,
               symbol: "TKB1"
             } = contract1
    end
  end
end
