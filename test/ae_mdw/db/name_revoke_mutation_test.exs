defmodule AeMdw.Db.NameRevokeMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.NameRevokeMutation

  require Model

  test "revoke a active name" do
    plain_name = "revoke.test"

    name_hash =
      case :aens.get_name_hash(plain_name) do
        {:ok, name_id_bin} -> :aeser_api_encoder.encode(:name, name_id_bin)
        _error -> nil
      end

    revoke_height = 3
    revoke_block_index = {revoke_height, 0}
    revoke_txi = 124

    expire = 100
    owner_pk = <<538_053::256>>

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

    Database.dirty_write(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
    Database.dirty_write(Model.ActiveName, active_name)

    Database.dirty_write(
      Model.ActiveNameExpiration,
      Model.expiration(index: {expire, plain_name})
    )

    Database.dirty_write(Model.ActiveNameOwner, Model.owner(index: {owner_pk, plain_name}))

    Database.commit([NameRevokeMutation.new(name_hash, revoke_txi, revoke_block_index)])

    assert {:ok,
            Model.name(
              index: ^plain_name,
              expire: ^expire,
              owner: ^owner_pk,
              revoke: {^revoke_block_index, ^revoke_txi}
            )} = Database.fetch(Model.InactiveName, plain_name)

    assert Database.exists?(Model.InactiveNameExpiration, {revoke_height, plain_name})
    assert Database.exists?(Model.InactiveNameOwner, {owner_pk, plain_name})
  end
end
