defmodule AeMdw.TestUtil do
  @moduledoc """
  Test helper functions imported by default on all tests.
  """

  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Database
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.State
  alias AeMdw.Db.MemStore
  alias Plug.Conn

  @spec handle_input((() -> Conn.t())) :: Conn.t() | String.t()
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
end
