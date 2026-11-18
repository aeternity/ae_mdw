defmodule AeMdw.Sync.MemStoreCreatorTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Sync.MemStoreCreator

  @lifetime_key {MemStoreCreator, :memstore_lifetime_secs}

  setup do
    global_state = :persistent_term.get(:global_state, :none)
    lifetime = :persistent_term.get(@lifetime_key, :none)
    :persistent_term.put(@lifetime_key, 0)

    on_exit(fn ->
      restore(:global_state, global_state)
      restore(@lifetime_key, lifetime)
    end)

    {:ok, state} = MemStoreCreator.init(:ok)

    {:ok, state: state}
  end

  test "deletes a store once it has been retired for longer than the lifetime", %{state: state} do
    {store1, state} = create(state)
    {store2, state} = create(state)
    set_global(store2)

    state = commit(state, store2)

    assert alive?(store1)
    assert_receive :sweep, 2_000

    state = sweep(state)

    refute alive?(store1)
    assert alive?(store2)
    assert [%{store: ^store2}] = state.stores
  end

  test "keeps the committed, previous committed, newest and global stores", %{state: state} do
    {global, state} = create(state)
    {prev_commited, state} = create(state)
    {unused, state} = create(state)
    {commited, state} = create(state)
    {newest, state} = create(state)
    set_global(global)

    state = state |> commit(prev_commited) |> commit(commited)
    assert_receive :sweep, 2_000
    _state = sweep(state)

    refute alive?(unused)
    assert Enum.all?([global, prev_commited, commited, newest], &alive?/1)
  end

  test "keeps a retired store that is the global store again", %{state: state} do
    {store1, state} = create(state)
    {store2, state} = create(state)
    set_global(store2)

    state = commit(state, store2)
    set_global(store1)
    assert_receive :sweep, 2_000
    _state = sweep(state)

    assert alive?(store1)
  end

  defp create(state) do
    {:reply, store, state} =
      MemStoreCreator.handle_call({:create, NullStore.new()}, {self(), make_ref()}, state)

    {store, state}
  end

  defp commit(state, store) do
    {:noreply, state} = MemStoreCreator.handle_cast({:commit, store}, state)
    state
  end

  defp sweep(state) do
    {:noreply, state} = MemStoreCreator.handle_info(:sweep, state)
    state
  end

  defp set_global(store), do: :persistent_term.put(:global_state, State.new(store))

  defp alive?(%MemStore{tables: tables}),
    do: Enum.all?(tables, fn {_name, table} -> :ets.info(table) != :undefined end)

  defp restore(key, :none), do: :persistent_term.erase(key)
  defp restore(key, value), do: :persistent_term.put(key, value)
end
