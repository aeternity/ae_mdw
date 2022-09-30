defmodule AeMdw.Db.Sync.OracleTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.Sync.Oracle
  alias AeMdw.Validate

  require Model

  describe "register_mutations/4" do
    test "registers an oracle on :oracle_register_tx putting its origin", %{store: store} do
      pubkey =
        <<11, 180, 237, 121, 39, 249, 123, 81, 225, 188, 181, 225, 52, 13, 18, 51, 91, 42, 43, 18,
          200, 188, 82, 33, 214, 60, 75, 203, 57, 212, 30, 97>>

      sync_height = 50_000
      ttl = 10_000
      expire = sync_height + ttl
      txi = sync_height * 1000

      tx_hash = Validate.id!("th_WQ9yMkEFe45drDzGEnhnYanH5Rov2ewAkjzbwcPzX32krZRyG")

      tx =
        {:oracle_register_tx, {:id, :account, pubkey}, 8904, "{\"bla\": str}", "{\"bla\": str}",
         ttl, {:delta, ttl}, 2_000_000_000_000_000_000, 0, 0}

      store = change_store(store, Oracle.register_mutations(tx, tx_hash, {sync_height, 0}, txi))

      assert {:ok, Model.oracle(index: ^pubkey, expire: ^expire)} =
               Store.get(store, Model.ActiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^expire, ^pubkey})} =
               Store.get(store, Model.ActiveOracleExpiration, {expire, pubkey})

      assert {:ok, Model.rev_origin(index: {^txi, :oracle_register_tx, ^pubkey})} =
               Store.get(store, Model.RevOrigin, {txi, :oracle_register_tx, pubkey})

      assert :not_found = Store.get(store, Model.InactiveOracle, pubkey)
      assert :not_found = Store.get(store, Model.InactiveOracleExpiration, {expire, pubkey})
    end
  end
end
