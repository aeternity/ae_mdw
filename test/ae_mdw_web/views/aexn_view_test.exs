defmodule AeMdwWeb.AexnViewTest do
  use ExUnit.Case

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
      extensions = ["ext1", "ext2"]

      state =
        NullStore.new()
        |> MemStore.new()
        |> State.new()
        |> Stats.decrement_aex9_holders(contract_pk)

      m_aex9 =
        Model.aexn_contract(
          index: {:aex9, contract_pk},
          txi: txi,
          meta_info: aex9_meta_info,
          extensions: extensions
        )

      assert %{
               name: ^name,
               symbol: ^symbol,
               decimals: ^decimals,
               contract_txi: ^txi,
               contract_id: ^contract_id,
               extensions: ^extensions,
               holders: "NA"
             } = AexnView.render_contract(state, m_aex9)
    end
  end
end
