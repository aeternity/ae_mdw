defmodule AeMdw.Db.UpdateIdsCountsMutation do
  @moduledoc """
  Updates the count of ocurrences of blockchain ids/pubkeys.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.IdCounter

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:ids_counts]

  @typep update_key :: {Model.id_count_index(), integer()}

  @opaque t() :: %__MODULE__{
            ids_counts: [update_key()]
          }

  @spec new([update_key()]) :: t()
  def new(ids_counts) do
    %__MODULE__{ids_counts: ids_counts}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{ids_counts: ids_counts}, state) do
    Enum.reduce(ids_counts, state, fn {id_count_key, delta}, state ->
      IdCounter.update_count(state, id_count_key, -delta)
    end)
  end
end
