defmodule AeMdw.Db.WriteTxnMutation do
  @moduledoc """
  This is the most basic kind of transaction, it just inserts a record in a
  mnesia table.
  """

  alias AeMdw.Database
  alias AeMdw.Db.State

  @derive AeMdw.Db.TxnMutation
  defstruct [:table, :record]

  @opaque t() :: %__MODULE__{
            table: Database.table(),
            record: Database.record()
          }

  @spec new(Database.table(), Database.record()) :: t()
  def new(table, record) do
    %__MODULE__{table: table, record: record}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{table: table, record: record}, state) do
    State.put(state, table, record)
  end
end
