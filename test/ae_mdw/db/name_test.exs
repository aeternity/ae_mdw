defmodule AeMdw.Db.NameTest do
  use ExUnit.Case

  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Name
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Store

  import AeMdwWeb.BlockchainSim, only: [with_blockchain: 3, name_tx: 3, name_tx: 4]
  import AeMdw.Util.Encoding
  import Mock

  require Model

  describe "pointers/2" do
    test "get pointer with non-string pointer key" do
      name = "binarypointers.chain"

      non_string_pointer_key =
        <<104, 65, 117, 174, 49, 251, 29, 202, 69, 174, 147, 56, 60, 150, 188, 247, 149, 85, 150,
          148, 88, 102, 186, 208, 87, 101, 78, 111, 189, 5, 144, 101>>

      non_string_pointer_key_list = :erlang.binary_to_list(non_string_pointer_key)

      with_blockchain %{alice: 1_000, celia: 1_000},
        mb: [
          tx1: name_tx(:name_claim_tx, :alice, name),
          tx2:
            name_tx(:name_update_tx, :alice, name, %{
              pointers: [{:pointer, non_string_pointer_key, :celia}]
            })
        ] do
        %{txs: [tx1, tx2]} = blocks[:mb]
        {:id, :account, celia_pk} = accounts[:celia]
        celia_id = encode(:account_pubkey, celia_pk)

        store =
          NullStore.new()
          |> MemStore.new()
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1, id: :aetx_sign.hash(tx1), block_index: {1, 1})
          )
          |> Store.put(
            Model.Tx,
            Model.tx(index: 2, id: :aetx_sign.hash(tx2), block_index: {1, 1})
          )

        assert pointers =
                 Name.pointers(
                   State.new(store),
                   Model.name(
                     index: name,
                     updates: [{{1, 1}, 2}]
                   )
                 )

        assert pointers == %{
                 non_string_pointer_key_list => celia_id
               }

        assert {:ok, _} = Phoenix.json_library().encode(pointers)
      end
    end
  end
end
