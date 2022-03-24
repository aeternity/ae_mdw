defmodule AeMdw.Db.NameUpdateMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.NameUpdateMutation

  require Model

  import AeMdw.Node.AeTxFixtures

  describe "update" do
    test "deactives a name by ttl 0" do
      owner_pk = <<123_456::256>>
      plain_name = "update-tll-0.test"
      tx = new_aens_update_tx(owner_pk, plain_name, 0)

      update_height = 10
      expire = update_height + 100

      active_name =
        Model.name(
          index: plain_name,
          active: 1,
          expire: expire,
          claims: [{{1, 0}, 123}],
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
        Model.ActiveNameExpiration,
        Model.expiration(index: {expire, plain_name})
      )

      Database.dirty_write(Model.ActiveNameOwner, Model.owner(index: {owner_pk, plain_name}))

      block_index = {update_height, 0}
      txi = 124
      Database.commit([NameUpdateMutation.new(tx, txi, block_index)])

      assert {:ok,
              Model.name(
                index: ^plain_name,
                expire: ^expire,
                owner: ^owner_pk,
                updates: [{^block_index, ^txi}],
                revoke: nil
              )} = Database.fetch(Model.InactiveName, plain_name)

      assert Database.exists?(Model.InactiveNameExpiration, {update_height, plain_name})
      assert Database.exists?(Model.InactiveNameOwner, {owner_pk, plain_name})
    end
  end
end
