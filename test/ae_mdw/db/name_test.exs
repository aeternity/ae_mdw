defmodule AeMdw.Db.NameTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Name
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Store

  import Mock

  require Model

  describe "pointers/2" do
    test "gets pointer with non-string pointer key" do
      name = "binarypointer.chain"
      pointer_id = :aeser_id.create(:account, <<1::256>>)

      non_string_pointer_key =
        <<104, 65, 117, 174, 49, 251, 29, 202, 69, 174, 147, 56, 60, 150, 188, 247, 149, 85, 150,
          148, 88, 102, 186, 208, 87, 101, 78, 111, 189, 5, 144, 101>>

      non_string_pointer_key_list = :erlang.binary_to_list(non_string_pointer_key)

      tx_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.Node, [:passthrough],
         [
           id_type: fn :account -> :account_pubkey end
         ]},
        {AeMdw.Node.Db, [:passthrough],
         [
           get_tx_data: fn ^tx_hash ->
             {:ok, name_hash} = :aens.get_name_hash(name)

             {:ok, aetx} =
               :aens_update_tx.new(%{
                 account_id: :aeser_id.create(:account, <<2::256>>),
                 nonce: 1,
                 name_id: :aeser_id.create(:name, name_hash),
                 name_ttl: 1_000,
                 pointers: [{:pointer, non_string_pointer_key, pointer_id}],
                 client_ttl: 1_000,
                 fee: 5_000
               })

             {_mod, tx_rec} = :aetx.specialize_type(aetx)
             {nil, :name_update_tx, nil, tx_rec}
           end
         ]}
      ] do
        store =
          NullStore.new()
          |> MemStore.new()
          |> Store.put(
            Model.Tx,
            Model.tx(index: 2, id: tx_hash, block_index: {1, 1})
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
                 non_string_pointer_key_list => Format.enc_id(pointer_id)
               }

        assert {:ok, _} = Phoenix.json_library().encode(pointers)
      end
    end
  end
end
