defmodule AeMdwWeb.AexnViewTest do
  use ExUnit.Case

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats
  alias AeMdwWeb.AexnView

  import AeMdw.Util.Encoding

  require Model

  describe "render_contract/3" do
    test "returns NA for invalid amount of holders" do
      contract_pk = :crypto.strong_rand_bytes(32)
      contract_id = encode_contract(contract_pk)
      aex9_meta_info = {name, symbol, decimals} = {"Token1", "TK1", 18}
      txi = 1_123_456_789
      decoded_tx_hash = <<txi::256>>
      tx_hash = Enc.encode(:tx_hash, decoded_tx_hash)

      extensions = ["ext1", "ext2"]

      m_tx = Model.tx(index: txi, id: decoded_tx_hash)

      m_aex9 =
        Model.aexn_contract(
          index: {:aex9, contract_pk},
          txi_idx: {txi, -1},
          meta_info: aex9_meta_info,
          extensions: extensions
        )

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> Stats.decrement_aex9_holders(contract_pk)
        |> State.put(Model.Tx, m_tx)

      assert %{
               name: ^name,
               symbol: ^symbol,
               decimals: ^decimals,
               contract_txi: ^txi,
               contract_id: ^contract_id,
               extensions: ^extensions,
               holders: 0
             } = AexnView.render_contract(state, m_aex9, false)

      assert %{
               name: ^name,
               symbol: ^symbol,
               decimals: ^decimals,
               contract_tx_hash: ^tx_hash,
               contract_id: ^contract_id,
               extensions: ^extensions
             } = AexnView.render_contract(state, m_aex9, true)
    end
  end
end
