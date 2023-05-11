defmodule AeMdw.Db.DeleteKeysMutation do
  @moduledoc """
  Deletes multiple keys from multiple tables in the same transaction.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:tables_keys]

  @typep tables_keys :: %{Model.table() => Range.t() | [Model.key()]}

  @opaque t() :: %__MODULE__{
            tables_keys: tables_keys()
          }

  @spec new(tables_keys()) :: t()
  def new(tables_keys) do
    %__MODULE__{tables_keys: tables_keys}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{tables_keys: tables_keys}, state) do
    Enum.reduce(tables_keys, state, fn {table, keys}, state ->
      Enum.reduce(keys, state, &safe_delete(&2, table, &1))
    end)
  end

  defp safe_delete(state, table, key) do
    if State.exists?(state, table, key) do
      State.delete(state, table, key)
    else
      state
    end
  end
end
