defmodule AeMdw.Db.OracleRegisterMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.OracleRegisterMutation

  require Model

  describe "execute" do
    test "replaces an active oracle", %{store: store} do
      height = Enum.random(1_000..500_000)
      block_index = {height, 1}
      txi = 1_000_000

      ttl = 5_000
      pubkey = <<1::256>>
      new_expire = height + ttl - 1

      mutation =
        OracleRegisterMutation.new(
          pubkey,
          block_index,
          new_expire,
          txi
        )

      old_height = height - 100
      old_expire = height - 1

      m_previous =
        Model.oracle(
          index: pubkey,
          active: old_height,
          expire: old_expire,
          register: {{old_height, 0}, txi - 1_000}
        )

      store =
        store
        |> Store.put(Model.ActiveOracle, m_previous)
        |> Store.put(
          Model.ActiveOracleExpiration,
          Model.expiration(index: {old_expire, pubkey})
        )
        |> change_store([mutation])

      assert {:ok,
              Model.oracle(
                index: ^pubkey,
                active: ^height,
                expire: ^new_expire,
                register: {^block_index, ^txi},
                previous: ^m_previous
              )} = Store.get(store, Model.ActiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^new_expire, ^pubkey})} =
               Store.get(store, Model.ActiveOracleExpiration, {new_expire, pubkey})

      assert :not_found = Store.get(store, Model.ActiveOracleExpiration, {old_expire, pubkey})
    end

    test "reactivates an inactive oracle", %{store: store} do
      height = Enum.random(1_000..500_000)
      block_index = {height, 2}
      txi = 1_000_000

      ttl = 5_000
      pubkey = <<2::256>>
      new_expire = height + ttl - 1

      mutation =
        OracleRegisterMutation.new(
          pubkey,
          block_index,
          new_expire,
          txi
        )

      old_height = height - 100
      old_expire = height - 1

      m_previous =
        Model.oracle(
          index: pubkey,
          active: old_height,
          expire: old_expire,
          register: {{old_height, 0}, txi - 1_000}
        )

      store =
        store
        |> Store.put(Model.InactiveOracle, m_previous)
        |> Store.put(
          Model.InactiveOracleExpiration,
          Model.expiration(index: {old_expire, pubkey})
        )
        |> change_store([mutation])

      assert :not_found = Store.get(store, Model.InactiveOracle, pubkey)
      assert :not_found = Store.get(store, Model.InactiveOracleExpiration, {old_expire, pubkey})

      assert {:ok,
              Model.oracle(
                index: ^pubkey,
                active: ^height,
                expire: ^new_expire,
                register: {^block_index, ^txi},
                previous: ^m_previous
              )} = Store.get(store, Model.ActiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^new_expire, ^pubkey})} =
               Store.get(store, Model.ActiveOracleExpiration, {new_expire, pubkey})
    end

    test "registers a new oracle", %{store: store} do
      height = Enum.random(1_000..500_000)
      block_index = {height, 2}
      txi = 1_000_000

      ttl = 5_000
      pubkey = <<3::256>>
      new_expire = height + ttl - 1

      mutation =
        OracleRegisterMutation.new(
          pubkey,
          block_index,
          new_expire,
          txi
        )

      assert :not_found = Store.get(store, Model.InactiveOracle, pubkey)
      assert :not_found = Store.get(store, Model.ActiveOracle, pubkey)

      store = change_store(store, [mutation])

      assert {:ok,
              Model.oracle(
                index: ^pubkey,
                active: ^height,
                expire: ^new_expire,
                register: {^block_index, ^txi},
                previous: nil
              )} = Store.get(store, Model.ActiveOracle, pubkey)

      assert {:ok, Model.expiration(index: {^new_expire, ^pubkey})} =
               Store.get(store, Model.ActiveOracleExpiration, {new_expire, pubkey})
    end
  end
end
