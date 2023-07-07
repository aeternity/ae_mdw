defmodule AeMdw.Db.TypeCountersMutation do
  @moduledoc """
  Increments the transaction type counts.
  """

  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Node

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:type_counts]

  @typep type_counts() :: %{Node.tx_type() => pos_integer()}
  @opaque t() :: %__MODULE__{
            type_counts: type_counts()
          }

  @spec new(type_counts()) :: t()
  def new(type_counts), do: %__MODULE__{type_counts: type_counts}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{type_counts: type_counts}, state) do
    Enum.reduce(type_counts, state, fn {tx_type, type_increment}, state ->
      State.update(
        state,
        Model.TypeCount,
        tx_type,
        fn Model.type_count(count: count) = type_count ->
          Model.type_count(type_count, count: count + type_increment)
        end,
        Model.type_count(index: tx_type, count: 0)
      )
    end)
  end
end
