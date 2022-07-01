defmodule AeMdw.Db.NameRevokeMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
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

    active_from = 11
    expire = 100
    owner_pk = <<538_053::256>>

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

    Database.dirty_write(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
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

    state2 =
      State.commit_mem(State.new(), [
        NameRevokeMutation.new(name_hash, revoke_txi, revoke_block_index)
      ])

    refute State.exists?(state2, Model.ActiveName, plain_name)
    refute State.exists?(state2, Model.ActiveNameOwner, {owner_pk, plain_name})
    refute State.exists?(state2, Model.ActiveNameActivation, {active_from, plain_name})
    refute State.exists?(state2, Model.ActiveNameExpiration, {expire, plain_name})

    assert {:ok,
            Model.name(
              index: ^plain_name,
              expire: ^expire,
              owner: ^owner_pk,
              revoke: {^revoke_block_index, ^revoke_txi}
            )} = State.get(state2, Model.InactiveName, plain_name)

    assert State.exists?(state2, Model.InactiveNameExpiration, {revoke_height, plain_name})
    assert State.exists?(state2, Model.InactiveNameOwner, {owner_pk, plain_name})
  end
end
