defmodule AeMdw.Db.NameUpdateMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Db.NameUpdateMutation

  require Model

  import AeMdw.Node.AeTxFixtures

  describe "update" do
    test "deactives a name by ttl 0", %{store: store} do
      owner_pk = <<123_456::256>>
      plain_name = "update-tll-0.test"
      tx = new_aens_update_tx(owner_pk, plain_name, 0)
      name_hash = :aens_update_tx.name_hash(tx)
      pointers = :aens_update_tx.pointers(tx)

      active_from = 9
      update_height = 10
      expire = update_height + 100

      active_name =
        Model.name(
          index: plain_name,
          active: active_from,
          expire: expire,
          revoke: nil,
          owner: owner_pk
        )

      state =
        store
        |> Store.put(
          Model.PlainName,
          Model.plain_name(index: name_hash, value: plain_name)
        )
        |> Store.put(Model.ActiveName, active_name)
        |> Store.put(
          Model.ActiveNameActivation,
          Model.activation(index: {active_from, plain_name})
        )
        |> Store.put(
          Model.ActiveNameExpiration,
          Model.expiration(index: {expire, plain_name})
        )
        |> Store.put(Model.ActiveNameOwner, Model.owner(index: {owner_pk, plain_name}))
        |> State.new()

      block_index = {update_height, 0}
      txi = 124

      state2 =
        State.commit_mem(state, [
          NameUpdateMutation.new(name_hash, :expire, pointers, {txi, -1}, block_index)
        ])

      assert {:ok,
              Model.name(
                index: ^plain_name,
                expire: ^update_height,
                owner: ^owner_pk,
                active: active,
                revoke: nil
              )} = State.get(state2, Model.InactiveName, plain_name)

      refute State.exists?(state2, Model.ActiveName, plain_name)
      refute State.exists?(state2, Model.ActiveNameOwner, {owner_pk, plain_name})
      refute State.exists?(state2, Model.ActiveNameActivation, {active_from, plain_name})
      refute State.exists?(state2, Model.ActiveNameExpiration, {expire, plain_name})
      assert State.exists?(state2, Model.InactiveNameExpiration, {update_height, plain_name})
      assert State.exists?(state2, Model.InactiveNameOwner, {owner_pk, plain_name})
      assert State.exists?(state2, Model.NameUpdate, {plain_name, active, {txi, -1}})
    end

    test "extends a name by a delta ttl > 0", %{store: store} do
      owner_pk = <<123_456::256>>
      delta_ttl = 121
      plain_name = "update-tll#{delta_ttl}.test"
      tx = new_aens_update_tx(owner_pk, plain_name, delta_ttl)
      name_hash = :aens_update_tx.name_hash(tx)
      pointers = :aens_update_tx.pointers(tx)

      active_from = 19
      update_height = 20
      expire = update_height + 100

      active_name =
        Model.name(
          index: plain_name,
          active: active_from,
          expire: expire,
          revoke: nil,
          owner: owner_pk
        )

      state =
        store
        |> Store.put(
          Model.PlainName,
          Model.plain_name(index: :aens_update_tx.name_hash(tx), value: plain_name)
        )
        |> Store.put(Model.ActiveName, active_name)
        |> Store.put(
          Model.ActiveNameActivation,
          Model.activation(index: {active_from, plain_name})
        )
        |> Store.put(
          Model.ActiveNameExpiration,
          Model.expiration(index: {expire, plain_name})
        )
        |> Store.put(Model.ActiveNameOwner, Model.owner(index: {owner_pk, plain_name}))
        |> State.new()

      new_expire = update_height + delta_ttl
      block_index = {update_height, 0}
      txi = 2234

      state2 =
        State.commit_mem(state, [
          NameUpdateMutation.new(
            name_hash,
            {:update_expiration, new_expire},
            pointers,
            {txi, -1},
            block_index
          )
        ])

      assert {:ok,
              Model.name(
                index: ^plain_name,
                expire: ^new_expire,
                owner: ^owner_pk,
                revoke: nil
              )} = State.get(state2, Model.ActiveName, plain_name)

      assert State.exists?(state2, Model.ActiveName, plain_name)
      assert State.exists?(state2, Model.ActiveNameOwner, {owner_pk, plain_name})
      assert State.exists?(state2, Model.ActiveNameActivation, {active_from, plain_name})
      assert State.exists?(state2, Model.ActiveNameExpiration, {new_expire, plain_name})
      refute State.exists?(state2, Model.ActiveNameExpiration, {expire, plain_name})
      refute State.exists?(state2, Model.InactiveNameExpiration, {update_height, plain_name})
      refute State.exists?(state2, Model.InactiveNameOwner, {owner_pk, plain_name})
      assert State.exists?(state2, Model.NameUpdate, {plain_name, active_from, {txi, -1}})
    end
  end
end
