defmodule AeMdw.Db.OracleInvalidationMutation do
  @moduledoc """
  Invalidates oracle tables records for a certain height.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync

  @derive AeMdw.Db.TxnMutation
  defstruct [:keys_delete, :records_write]

  @type table_keys :: {Model.table(), [Model.key()]}
  @type table_records :: {Model.table(), [Model.m_record()]}

  @opaque t() :: %__MODULE__{
            keys_delete: list(table_keys),
            records_write: list(table_records)
          }

  @spec new(AeMdw.Blocks.height()) :: t()
  def new(height) do
    {name_dels, name_writes} = Sync.Name.invalidate(height)
    %__MODULE__{keys_delete: name_dels, records_write: name_writes}
  end

  @spec execute(t(), AeMdw.Database.transaction()) :: :ok
  def execute(%__MODULE__{keys_delete: keys_delete, records_write: records_write}, txn) do
    Enum.each(keys_delete, fn {tab, keys} ->
      Enum.each(keys, fn key -> AeMdw.Db.Name.cache_through_delete(txn, tab, key) end)
    end)

    Enum.each(records_write, fn {tab, records} ->
      Enum.each(records, fn record -> AeMdw.Db.Name.cache_through_write(txn, tab, record) end)
    end)
  end
end
