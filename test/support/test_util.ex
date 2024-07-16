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
  alias AeMdw.Db.UpdateBalanceAccountMutation
  alias AeMdw.Error.Input, as: ErrInput
  alias Plug.Conn

  @type key :: term()

  @spec empty_store() :: MemStore.t()
  def empty_store, do: MemStore.new(NullStore.new())

  @spec empty_state() :: State.t()
  def empty_state, do: State.new(empty_store())

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
