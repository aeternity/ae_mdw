defmodule AeMdw.Db.DeleteKeysMutation do
  @moduledoc """
  Deletes multiple keys from multiple tables in the same transaction.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Database

  require Model

  @derive AeMdw.Db.TxnMutation
  defstruct [:tables_keys]

  @typep tables_keys :: %{Model.table() => Range.t() | [Model.key()]}

  @opaque t() :: %__MODULE__{
            tables_keys: tables_keys()
          }

  @spec new(tables_keys()) :: t()
  def new(tables_keys) do
    %__MODULE__{tables_keys: tables_keys}
  end

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(%__MODULE__{tables_keys: tables_keys}, txn) do
    Enum.each(tables_keys, fn {table, keys} ->
      Enum.each(keys, &Database.delete(txn, table, &1))
    end)
  end
end
