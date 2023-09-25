defmodule AeMdw.Db.NamesExpirationMutationTest do
  use AeMdw.Db.MutationCase

  alias AeMdw.Db.Model
  alias AeMdw.Db.NamesExpirationMutation
  alias AeMdw.Db.Store

  require Model

  describe "execute" do
    test "inactivates a name that has just expired", %{store: store} do
      plain_name = "some-active-name"
      sync_height = 100_000
      active_height = sync_height - 5_000

      m_name =
        Model.name(
          index: plain_name,
          active: active_height,
          expire: sync_height,
          owner: <<2::256>>
        )

      m_exp = Model.expiration(index: {sync_height, plain_name})

      store =
        store
        |> Store.put(Model.ActiveName, m_name)
        |> Store.put(Model.ActiveNameExpiration, m_exp)

      mutation = NamesExpirationMutation.new(sync_height)
      store = change_store(store, [mutation])

      assert :not_found = Store.get(store, Model.ActiveName, plain_name)
      assert :not_found = Store.get(store, Model.ActiveNameExpiration, {sync_height, plain_name})

      assert {:ok, ^m_name} = Store.get(store, Model.InactiveName, plain_name)

      assert {:ok, ^m_exp} =
               Store.get(store, Model.InactiveNameExpiration, {sync_height, plain_name})
    end

    test "does nothing when name has not expired yet", %{store: store} do
      plain_name = "some-expired-name"
      sync_height = 100_000

      active_height = sync_height - 5_000

      m_name =
        Model.name(
          index: plain_name,
          active: active_height,
          expire: sync_height + 1,
          owner: <<2::256>>
        )

      m_exp = Model.expiration(index: {sync_height + 1, plain_name})

      store =
        store
        |> Store.put(Model.ActiveName, m_name)
        |> Store.put(Model.ActiveNameExpiration, m_exp)

      mutation = NamesExpirationMutation.new(sync_height)
      store = change_store(store, [mutation])

      assert {:ok, ^m_name} = Store.get(store, Model.ActiveName, plain_name)

      assert {:ok, ^m_exp} =
               Store.get(store, Model.ActiveNameExpiration, {sync_height + 1, plain_name})
    end

    test "does nothing when name is already inactive", %{store: store} do
      plain_name = "some-inactive-name"
      sync_height = 100_000

      active_height = sync_height - 5_000

      m_name =
        Model.name(
          index: plain_name,
          active: active_height,
          expire: sync_height - 1,
          owner: <<2::256>>
        )

      m_exp = Model.expiration(index: {sync_height - 1, plain_name})

      store =
        store
        |> Store.put(Model.InactiveName, m_name)
        |> Store.put(Model.InactiveNameExpiration, m_exp)

      mutation = NamesExpirationMutation.new(sync_height)
      store = change_store(store, [mutation])

      assert {:ok, ^m_name} = Store.get(store, Model.InactiveName, plain_name)

      assert {:ok, ^m_exp} =
               Store.get(store, Model.InactiveNameExpiration, {sync_height - 1, plain_name})
    end
  end
end
