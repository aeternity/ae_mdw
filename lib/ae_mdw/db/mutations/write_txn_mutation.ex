defmodule AeMdw.Db.WriteTxnMutation do
  @moduledoc """
  This is the most basic kind of transaction, it just inserts a record in a
  mnesia table.
  """

  alias AeMdw.Database

  defstruct [:table, :record]

  @opaque t() :: %__MODULE__{
            table: Database.table(),
            record: Database.record()
          }

  @spec new(Database.table(), Database.record()) :: t()
  def new(table, record) do
    %__MODULE__{table: table, record: record}
  end

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(%__MODULE__{table: table, record: record}, txn) do
    Database.write(txn, table, record)
  end
end

defimpl AeMdw.Db.TxnMutation, for: AeMdw.Db.WriteTxnMutation do
  def execute(mutation, txn) do
    @for.execute(mutation, txn)
  end
end
