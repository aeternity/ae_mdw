defmodule AeMdw.Db.IncrementTypeCountMutation do
  @moduledoc """
  Adds one to the type count.
  """

  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Node

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:type]

  @opaque t() :: %__MODULE__{
            type: Node.tx_type()
          }

  @spec new(Node.tx_type()) :: t()
  def new(type), do: %__MODULE__{type: type}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{type: tx_type}, state) do
    new_count =
      case State.get(state, Model.TypeCount, tx_type) do
        {:ok, Model.type_count(count: count)} -> count + 1
        :not_found -> 1
      end

    State.put(state, Model.TypeCount, Model.type_count(index: tx_type, count: new_count))
  end
end
