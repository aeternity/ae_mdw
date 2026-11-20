defmodule AeMdw.TestUtil do
  @moduledoc """
  Test helper functions imported by default on all tests.
  """
  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.ObjectKeys
  alias AeMdw.Db.UpdateBalanceAccountMutation
  alias AeMdw.Error.Input, as: ErrInput
  alias Plug.Conn

  @type key :: term()

  @spec empty_store() :: MemStore.t()
  def empty_store, do: MemStore.new(NullStore.new())

  @spec empty_state() :: State.t()
  def empty_state, do: State.new(empty_store())

  @doc """
  Setup callback that puts the global mem state back when the test ends, erasing it
  when there was none: `State.mem_state/0` returns any other value as the state.
  """
  @spec restore_global_state(map()) :: :ok
  def restore_global_state(_context) do
    global_state = :persistent_term.get(:global_state, :none)

    ExUnit.Callbacks.on_exit(fn ->
      case global_state do
        :none -> :persistent_term.erase(:global_state)
        _state -> :persistent_term.put(:global_state, global_state)
      end
    end)
  end

  Enum.each(AeMdw.Db.Model.tables(), fn table ->
    @spec all_keys(State.t(), unquote(table)) :: [key()]
  end)

  def all_keys(state, table), do: state |> Collection.stream(table, nil) |> Enum.to_list()

  @spec handle_input((-> Conn.t())) :: Conn.t() | String.t()
  def handle_input(f) do
    try do
      f.()
    rescue
      err in [ErrInput] ->
        err.message
    end
  end

  @spec with_store(Conn.t(), Store.t()) :: Conn.t()
  def with_store(conn, store) do
    Conn.assign(conn, :state, State.new(store))
  end

  @spec with_async_store(Conn.t(), Store.t()) :: Conn.t()
  def with_async_store(conn, async_store) do
    Conn.assign(conn, :async_state, State.new(async_store))
  end

  @spec change_store(MemStore.t(), [Mutation.t()]) :: Store.t()
  def change_store(store, mutations) do
    %{store: store2} =
      mutations
      |> List.flatten()
      |> Enum.reduce(State.new(store), fn mutation, state ->
        Mutation.execute(mutation, state)
      end)

    Enum.each(store2.tables, &Database.exists?(elem(&1, 0), nil))

    store2
  end

  @spec put_counted(
          MemStore.t(),
          ObjectKeys.table(),
          AeMdw.Db.Model.name() | AeMdw.Db.Model.oracle()
        ) ::
          MemStore.t()
  def put_counted(store, table, record) do
    %{store: store2} = store |> State.new() |> ObjectKeys.put(table, record)

    store2
  end

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep balances :: [{pubkey(), integer()}]
  @spec update_balances(State.t(), balances()) :: State.t()
  def update_balances(state, balances) do
    Enum.reduce(balances, state, fn {account_pk, balance}, acc ->
      account_pk
      |> UpdateBalanceAccountMutation.new(balance)
      |> Mutation.execute(acc)
    end)
  end
end
