defmodule AeMdw.Db.KeyBlockMutation do
  @moduledoc """
  Creates a key block and clears the stats cache.
  """

  alias AeMdw.Db.State
  alias AeMdw.Db.Model

  @derive AeMdw.Db.Mutation
  defstruct [:key_block]

  @opaque t() :: %__MODULE__{
            key_block: Model.block()
          }

  @spec new(Model.block()) :: t()
  def new(key_block) do
    %__MODULE__{key_block: key_block}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{key_block: key_block}, state) do
    state
    |> State.put(Model.Block, key_block)
    |> State.clear_stats()
    |> State.clear_cache()
  end
end
