defmodule AeMdw.Db.MnesiaWriteMutation do
  @moduledoc """
  This is the most basic kind of transaction, it just inserts a record in a
  mnesia table.
  """

  alias AeMdw.Mnesia

  defstruct [:table, :record]

  @opaque t() :: %__MODULE__{
            table: Mnesia.table(),
            record: Mnesia.record()
          }

  @spec new(Mnesia.table(), Mnesia.record()) :: t()
  def new(table, record) do
    %__MODULE__{table: table, record: record}
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{table: table, record: record}) do
    Mnesia.write(table, record)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.MnesiaWriteMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
