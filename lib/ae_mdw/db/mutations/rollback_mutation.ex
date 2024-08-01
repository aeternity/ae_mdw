defmodule AeMdw.Db.RollbackMutation do
  @moduledoc """
  Clears the DB entirely.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  @derive AeMdw.Db.Mutation
  defstruct []

  @opaque t() :: %__MODULE__{}

  @spec new() :: t()
  def new(), do: %__MODULE__{}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{}, state) do
    Model.tables()
    |> Enum.reduce(state, fn table_name, state ->
      state
      |> Collection.stream(table_name, nil)
      |> Enum.reduce(state, fn key, state ->
        State.delete(state, table_name, key)
      end)
    end)
  end
end
