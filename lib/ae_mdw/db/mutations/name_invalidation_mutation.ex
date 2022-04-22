defmodule AeMdw.Db.NameInvalidationMutation do
  @moduledoc """
  Invalidates name tables records for a certain height.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync

  @derive AeMdw.Db.Mutation
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

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{keys_delete: keys_delete, records_write: records_write}, state) do
    new_state =
      Enum.reduce(keys_delete, state, fn {tab, keys}, state ->
        Enum.reduce(keys, state, fn key, state -> Name.cache_through_delete(state, tab, key) end)
      end)

    Enum.reduce(records_write, new_state, fn {tab, records}, state ->
      Enum.reduce(records, state, fn record, state ->
        Name.cache_through_write(state, tab, record)
      end)
    end)
  end
end
