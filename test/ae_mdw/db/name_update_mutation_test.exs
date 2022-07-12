defmodule AeMdw.Db.NameUpdateMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.NameUpdateMutation

  require Model

  import AeMdw.Node.AeTxFixtures

  describe "update" do
    test "deactives a name by ttl 0" do
      owner_pk = <<123_456::256>>
      plain_name = "update-tll-0.test"
      tx = new_aens_update_tx(owner_pk, plain_name, 0)

      active_from = 9
      update_height = 10
      expire = update_height + 100

      active_name =
        Model.name(
          index: plain_name,
          active: active_from,
          expire: expire,
          claims: [{{active_from, 0}, 123}],
          updates: [],
          transfers: [],
          revoke: nil,
          owner: owner_pk,
          previous: nil
        )

      Database.dirty_write(
        Model.PlainName,
        Model.plain_name(index: :aens_update_tx.name_hash(tx), value: plain_name)
      )

      Database.dirty_write(Model.ActiveName, active_name)

      Database.dirty_write(
        Model.ActiveNameActivation,
        Model.activation(index: {active_from, plain_name})
      )

      Database.dirty_write(
        Model.ActiveNameExpiration,
        Model.expiration(index: {expire, plain_name})
      )

      Database.dirty_write(Model.ActiveNameOwner, Model.owner(index: {owner_pk, plain_name}))

      block_index = {update_height, 0}
      txi = 124
      state2 = State.commit_mem(State.new(), [NameUpdateMutation.new(tx, txi, block_index)])

      assert {:ok,
              Model.name(
                index: ^plain_name,
                expire: ^update_height,
                owner: ^owner_pk,
                updates: [{^block_index, ^txi}],
                revoke: nil
              )} = State.get(state2, Model.InactiveName, plain_name)

      refute State.exists?(state2, Model.ActiveName, plain_name)
      refute State.exists?(state2, Model.ActiveNameOwner, {owner_pk, plain_name})
      refute State.exists?(state2, Model.ActiveNameActivation, {active_from, plain_name})
      refute State.exists?(state2, Model.ActiveNameExpiration, {expire, plain_name})
      assert State.exists?(state2, Model.InactiveNameExpiration, {update_height, plain_name})
      assert State.exists?(state2, Model.InactiveNameOwner, {owner_pk, plain_name})
    end

    test "extends a name by a delta ttl > 0" do
      owner_pk = <<123_456::256>>
      delta_ttl = 121
      plain_name = "update-tll#{delta_ttl}.test"
      tx = new_aens_update_tx(owner_pk, plain_name, delta_ttl)

      active_from = 19
      update_height = 20
      expire = update_height + 100

      active_name =
        Model.name(
          index: plain_name,
          active: active_from,
          expire: expire,
          claims: [{{active_from, 0}, 1234}],
          updates: [],
          transfers: [],
          revoke: nil,
          owner: owner_pk,
          previous: nil
        )

      Database.dirty_write(
        Model.PlainName,
        Model.plain_name(index: :aens_update_tx.name_hash(tx), value: plain_name)
      )

      Database.dirty_write(Model.ActiveName, active_name)

      Database.dirty_write(
        Model.ActiveNameActivation,
        Model.activation(index: {active_from, plain_name})
      )

      Database.dirty_write(
        Model.ActiveNameExpiration,
        Model.expiration(index: {expire, plain_name})
      )

      Database.dirty_write(Model.ActiveNameOwner, Model.owner(index: {owner_pk, plain_name}))

      block_index = {update_height, 0}
      txi = 2234
      state2 = State.commit_mem(State.new(), [NameUpdateMutation.new(tx, txi, block_index)])

      new_expire = update_height + delta_ttl

      assert {:ok,
              Model.name(
                index: ^plain_name,
                expire: ^new_expire,
                owner: ^owner_pk,
                updates: [{^block_index, ^txi}],
                revoke: nil
              )} = State.get(state2, Model.ActiveName, plain_name)

      assert State.exists?(state2, Model.ActiveName, plain_name)
      assert State.exists?(state2, Model.ActiveNameOwner, {owner_pk, plain_name})
      assert State.exists?(state2, Model.ActiveNameActivation, {active_from, plain_name})
      assert State.exists?(state2, Model.ActiveNameExpiration, {new_expire, plain_name})
      refute State.exists?(state2, Model.ActiveNameExpiration, {expire, plain_name})
      refute State.exists?(state2, Model.InactiveNameExpiration, {update_height, plain_name})
      refute State.exists?(state2, Model.InactiveNameOwner, {owner_pk, plain_name})
    end
  end
end
