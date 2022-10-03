defmodule AeMdw.Db.OraclesExpirationMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.OraclesExpirationMutation
  alias AeMdw.Db.Store

  require Model

  describe "execute" do
    test "inactivates an oracle that has just expired", %{store: store} do
      pubkey = <<123_451::256>>
      sync_height = 10_000

      m_oracle =
        Model.oracle(
          index: pubkey,
          expire: sync_height,
          register: {{sync_height - 5_000, 0}, 1_234},
          extends: nil,
          previous: nil
        )

      store =
        store
        |> Store.put(Model.ActiveOracle, m_oracle)
        |> Store.put(Model.ActiveOracleExpiration, Model.expiration(index: {sync_height, pubkey}))

      mutation = OraclesExpirationMutation.new(sync_height)
      store = change_store(store, [mutation])

      assert :not_found = Store.get(store, Model.ActiveOracleExpiration, {sync_height, pubkey})

      assert {:ok, ^m_oracle} = Store.get(store, Model.InactiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^sync_height, ^pubkey})} =
               Store.get(store, Model.InactiveOracleExpiration, {sync_height, pubkey})
    end

    test "does nothing when oracle has not expired yet",
         %{store: store} do
      pubkey = <<123_452::256>>
      sync_height = 10_000
      expire = sync_height + 1

      m_oracle =
        Model.oracle(
          index: pubkey,
          expire: expire,
          register: {{expire - 5_000, 0}, 1_234},
          extends: nil,
          previous: nil
        )

      store =
        store
        |> Store.put(Model.ActiveOracle, m_oracle)
        |> Store.put(Model.ActiveOracleExpiration, Model.expiration(index: {expire, pubkey}))

      mutation = OraclesExpirationMutation.new(sync_height)
      store = change_store(store, [mutation])

      assert :not_found = Store.get(store, Model.InactiveOracle, pubkey)
      assert :not_found = Store.get(store, Model.InactiveOracleExpiration, {sync_height, pubkey})

      assert {:ok, ^m_oracle} = Store.get(store, Model.ActiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^expire, ^pubkey})} =
               Store.get(store, Model.ActiveOracleExpiration, {expire, pubkey})
    end

    test "does nothing when oracle is already inactive", %{store: store} do
      pubkey = <<123_453::256>>
      sync_height = 10_000
      expire = sync_height - 1

      m_oracle =
        Model.oracle(
          index: pubkey,
          expire: expire,
          register: {{expire - 5_000, 0}, 1_234},
          extends: nil,
          previous: nil
        )

      store =
        store
        |> Store.put(Model.InactiveOracle, m_oracle)
        |> Store.put(Model.InactiveOracleExpiration, Model.expiration(index: {expire, pubkey}))

      mutation = OraclesExpirationMutation.new(sync_height)
      store = change_store(store, [mutation])

      assert :not_found = Store.get(store, Model.ActiveOracle, pubkey)

      assert {:ok, ^m_oracle} = Store.get(store, Model.InactiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^expire, ^pubkey})} =
               Store.get(store, Model.InactiveOracleExpiration, {expire, pubkey})
    end
  end
end
