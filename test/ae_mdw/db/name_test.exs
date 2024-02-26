defmodule AeMdw.Db.NameTest do
  use ExUnit.Case, async: false

  alias AeMdw.Validate
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Name
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Util.Encoding

  import Mock

  require Model

  describe "pointers/2" do
    test "encodes non-string pointer key to base64" do
      name = "binarypointer.chain"
      pointer_id = :aeser_id.create(:account, <<1::256>>)
      oracle_id = :aeser_id.create(:oracle, <<1::256>>)

      non_string_pointer_key =
        <<104, 65, 117, 174, 49, 251, 29, 202, 69, 174, 147, 56, 60, 150, 188, 247, 149, 85, 150,
          148, 88, 102, 186, 208, 87, 101, 78, 111, 189, 5, 144, 101>>

      non_string_pointer_key64 = Base.encode64(non_string_pointer_key)
      active_height = 123
      tx_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
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
                 pointers: [
                   {:pointer, non_string_pointer_key, pointer_id},
                   {:pointer, "oracle_pubkey", oracle_id}
                 ],
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
          |> Store.put(Model.NameUpdate, Model.name_update(index: {name, active_height, {2, -1}}))

        pointers_map = %{
          non_string_pointer_key64 => Format.enc_id(pointer_id),
          "oracle_pubkey" => Format.enc_id(oracle_id)
        }

        assert ^pointers_map =
                 Name.pointers(
                   State.new(store),
                   Model.name(index: name, active: active_height)
                 )
      end
    end

    test "encodes custom string pointer key to base64" do
      name = "binarypointer.chain"
      pointer_id = :aeser_id.create(:account, <<1::256>>)
      channel_id = :aeser_id.create(:channel, <<2::256>>)
      custom_string_pointer_key = "family_pubkey"
      custom_string_pointer_key64 = Base.encode64(custom_string_pointer_key)
      tx_hash = :crypto.strong_rand_bytes(32)
      active_height = 123

      with_mocks [
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
                 pointers: [
                   {:pointer, "channel", channel_id},
                   {:pointer, custom_string_pointer_key, pointer_id}
                 ],
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
          |> Store.put(Model.NameUpdate, Model.name_update(index: {name, active_height, {2, -1}}))

        pointers_map = %{
          custom_string_pointer_key64 => Format.enc_id(pointer_id),
          "channel" => Format.enc_id(channel_id)
        }

        assert ^pointers_map =
                 Name.pointers(
                   State.new(store),
                   Model.name(index: name, active: active_height)
                 )
      end
    end
  end

  describe "last_update_pointee_pubkey/2" do
    test "returns the account pointee pubkey if present" do
      name = "nameaccountpointee.chain"
      pointer_id = :aeser_id.create(:account, :crypto.strong_rand_bytes(32))
      active_height = 1_123
      tx_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           get_tx_data: fn ^tx_hash ->
             {:ok, name_hash} = :aens.get_name_hash(name)

             {:ok, aetx} =
               :aens_update_tx.new(%{
                 account_id: :aeser_id.create(:account, :crypto.strong_rand_bytes(32)),
                 nonce: 1,
                 name_id: :aeser_id.create(:name, name_hash),
                 name_ttl: 80,
                 pointers: [
                   {:pointer, "account_pubkey", pointer_id}
                 ],
                 client_ttl: 80,
                 fee: 5_000
               })

             {_mod, tx_rec} = :aetx.specialize_type(aetx)
             {nil, :name_update_tx, nil, tx_rec}
           end
         ]}
      ] do
        {:ok, name_hash} = :aens.get_name_hash(name)

        state =
          NullStore.new()
          |> MemStore.new()
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1_124, id: tx_hash, block_index: {124, 1})
          )
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: name))
          |> Store.put(Model.InactiveName, Model.name(index: name, active: active_height))
          |> Store.put(
            Model.NameUpdate,
            Model.name_update(index: {name, active_height, {1_124, -1}})
          )
          |> State.new()

        account_id = Format.enc_id(pointer_id)
        account_pk = Validate.id!(account_id)

        assert %{"account_pubkey" => ^account_id} =
                 Name.pointers(
                   state,
                   Model.name(index: name, active: active_height)
                 )

        assert ^account_pk =
                 Name.last_update_pointee_pubkey(
                   state,
                   Encoding.encode(:name, name_hash)
                 )
      end
    end

    test "returns a different pointee pubkey when account is missing" do
      name = "nameoraclepointee.chain"
      pointer_id = :aeser_id.create(:account, :crypto.strong_rand_bytes(32))
      active_height = 1_123
      tx_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           get_tx_data: fn ^tx_hash ->
             {:ok, name_hash} = :aens.get_name_hash(name)

             {:ok, aetx} =
               :aens_update_tx.new(%{
                 account_id: :aeser_id.create(:account, :crypto.strong_rand_bytes(32)),
                 nonce: 1,
                 name_id: :aeser_id.create(:name, name_hash),
                 name_ttl: 80,
                 pointers: [
                   {:pointer, "oracle_pubkey", pointer_id}
                 ],
                 client_ttl: 80,
                 fee: 5_000
               })

             {_mod, tx_rec} = :aetx.specialize_type(aetx)
             {nil, :name_update_tx, nil, tx_rec}
           end
         ]}
      ] do
        {:ok, name_hash} = :aens.get_name_hash(name)

        state =
          NullStore.new()
          |> MemStore.new()
          |> Store.put(
            Model.Tx,
            Model.tx(index: 1_124, id: tx_hash, block_index: {124, 1})
          )
          |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: name))
          |> Store.put(Model.InactiveName, Model.name(index: name, active: active_height))
          |> Store.put(
            Model.NameUpdate,
            Model.name_update(index: {name, active_height, {1_124, -1}})
          )
          |> State.new()

        oracle_id = Format.enc_id(pointer_id)
        oracle_pk = Validate.id!(oracle_id)

        assert %{"oracle_pubkey" => ^oracle_id} =
                 Name.pointers(
                   state,
                   Model.name(index: name, active: active_height)
                 )

        assert ^oracle_pk =
                 Name.last_update_pointee_pubkey(
                   state,
                   Encoding.encode(:name, name_hash)
                 )
      end
    end
  end
end
