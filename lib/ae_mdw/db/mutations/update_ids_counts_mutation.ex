defmodule AeMdw.Db.UpdateIdsCountsMutation do
  @moduledoc """
  Updates the count of ocurrences of blockchain ids/pubkeys.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Db.Sync.IdCounter

  require Model

  @derive AeMdw.Db.TxnMutation
  defstruct [:ids_counts]

  @typep update_key :: {Model.id_count_key(), integer()}

  @opaque t() :: %__MODULE__{
    ids_counts: [update_key()]
  }

  @spec new([update_key()]) :: t()
  def new(ids_counts) do
    %__MODULE__{ids_counts: ids_counts}
  end

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(%__MODULE__{ids_counts: ids_counts}, txn) do
    Enum.each(ids_counts, fn {id_count_key, delta} -> IdCounter.update_count(txn, id_count_key, -delta) end)
  end
end
