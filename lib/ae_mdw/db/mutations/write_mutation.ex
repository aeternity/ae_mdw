defmodule AeMdw.Db.WriteMutation do
  @moduledoc """
  This is the most basic kind of transaction, it just inserts a record in a
  mnesia table.
  """

  alias AeMdw.Database

  @derive AeMdw.Db.Mutation
  defstruct [:table, :record]

  @opaque t() :: %__MODULE__{
            table: Database.table(),
            record: Database.record()
          }

  @spec new(Database.table(), Database.record()) :: t()
  def new(table, record) do
    %__MODULE__{table: table, record: record}
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{table: table, record: record}) do
    Database.write(table, record)
  end
end
