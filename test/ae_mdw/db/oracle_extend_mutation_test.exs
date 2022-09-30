defmodule AeMdw.Db.OracleExtendMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.OracleExtendMutation

  require Model

  describe "execute" do
    test "succeeds when oracle is active", %{store: store} do
      height = Enum.random(1_000..500_000)
      ttl = 5_000
      pubkey = <<1::256>>
      old_expire = height - 1
      new_expire = height + ttl - 1

      mutation =
        OracleExtendMutation.new(
          {height, 0},
          height * 1000,
          pubkey,
          ttl
        )

      store =
        store
        |> Store.put(Model.ActiveOracle, Model.oracle(index: pubkey, expire: old_expire))
        |> Store.put(
          Model.ActiveOracleExpiration,
          Model.expiration(index: {old_expire, pubkey})
        )
        |> change_store([mutation])

      assert {:ok, Model.oracle(index: ^pubkey, expire: ^new_expire)} =
               Store.get(store, Model.ActiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^new_expire, ^pubkey})} =
               Store.get(store, Model.ActiveOracleExpiration, {new_expire, pubkey})

      assert :not_found = Store.get(store, Model.ActiveOracleExpiration, {old_expire, pubkey})
    end

    test "do nothing when oracle is inactive", %{store: store} do
      height = Enum.random(1_000..500_000)
      ttl = 5_000
      pubkey = <<2::256>>
      old_expire = height - 1

      mutation =
        OracleExtendMutation.new(
          {height, 0},
          height * 1000,
          pubkey,
          ttl
        )

      store =
        store
        |> Store.put(Model.InactiveOracle, Model.oracle(index: pubkey, expire: old_expire))
        |> Store.put(
          Model.InactiveOracleExpiration,
          Model.expiration(index: {old_expire, pubkey})
        )
        |> change_store([mutation])

      assert :not_found = Store.get(store, Model.ActiveOracle, pubkey)

      assert {:ok, Model.oracle(index: ^pubkey)} = Store.get(store, Model.InactiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^old_expire, ^pubkey})} =
               Store.get(store, Model.InactiveOracleExpiration, {old_expire, pubkey})
    end
  end
end
