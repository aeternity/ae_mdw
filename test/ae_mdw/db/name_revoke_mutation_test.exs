defmodule AeMdw.Db.NameRevokeMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Store
  alias AeMdw.Db.NameRevokeMutation

  require Model

  test "revoke a active name", %{store: store} do
    plain_name = "revoke.test"

    {:ok, name_hash} = :aens.get_name_hash(plain_name)

    revoke_height = 3
    revoke_block_index = {revoke_height, 0}
    revoke_txi_idx = {124, -1}

    active_from = 11
    expire = 100
    owner_pk = <<538_053::256>>

    active_name =
      Model.name(
        index: plain_name,
        active: active_from,
        expire: expire,
        revoke: nil,
        owner: owner_pk,
        previous: nil
      )

    state =
      store
      |> Store.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
      |> Store.put(Model.ActiveName, active_name)
      |> Store.put(Model.ActiveNameActivation, Model.activation(index: {active_from, plain_name}))
      |> Store.put(Model.ActiveNameExpiration, Model.expiration(index: {expire, plain_name}))
      |> Store.put(Model.ActiveNameOwner, Model.owner(index: {owner_pk, plain_name}))
      |> State.new()

    state2 =
      NameRevokeMutation.execute(
        NameRevokeMutation.new(name_hash, revoke_txi_idx, revoke_block_index),
        state
      )

    refute State.exists?(state2, Model.ActiveName, plain_name)
    refute State.exists?(state2, Model.ActiveNameOwner, {owner_pk, plain_name})
    refute State.exists?(state2, Model.ActiveNameActivation, {active_from, plain_name})
    refute State.exists?(state2, Model.ActiveNameExpiration, {expire, plain_name})

    refute State.exists?(
             state2,
             Model.ActiveNameOwnerDeactivation,
             {owner_pk, expire, plain_name}
           )

    assert {:ok,
            Model.name(
              index: ^plain_name,
              expire: ^expire,
              owner: ^owner_pk,
              revoke: {^revoke_block_index, ^revoke_txi_idx}
            )} = State.get(state2, Model.InactiveName, plain_name)

    assert State.exists?(state2, Model.InactiveNameExpiration, {revoke_height, plain_name})
    assert State.exists?(state2, Model.InactiveNameOwner, {owner_pk, plain_name})

    assert State.exists?(
             state2,
             Model.InactiveNameOwnerDeactivation,
             {owner_pk, revoke_height, plain_name}
           )
  end
end
