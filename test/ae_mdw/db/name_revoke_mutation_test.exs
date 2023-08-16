defmodule AeMdw.Db.NameRevokeMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Sync.Name
  alias AeMdw.Db.NameRevokeMutation

  require Model

  test "revoke a active name" do
    plain_name = "revoke.test"
    {:ok, name_hash} = :aens.get_name_hash(plain_name)

    active_height = 100_000
    revoke_height = active_height + 1
    revoke_block_index = {revoke_height, 0}
    revoke_txi_idx = {1_000_000, -1}

    expire = active_height + 100
    owner_pk = TS.address(0)

    active_name =
      Model.name(
        index: plain_name,
        active: active_height,
        expire: expire,
        revoke: nil,
        owner: owner_pk,
        previous: nil
      )

    state1 =
      empty_state()
      |> State.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
      |> Name.put_active(active_name)

    state2 =
      empty_state()
      |> State.put(Model.PlainName, Model.plain_name(index: name_hash, value: plain_name))
      |> Name.put_active(active_name)

    state1 =
      NameRevokeMutation.execute(
        NameRevokeMutation.new(name_hash, revoke_txi_idx, revoke_block_index),
        state1
      )

    state2 = Name.revoke(state2, plain_name, revoke_txi_idx, revoke_block_index)

    assert_same(state1, state2)
  end
end
