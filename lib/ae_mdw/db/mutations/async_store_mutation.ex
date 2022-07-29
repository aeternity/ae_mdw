defmodule AeMdw.Db.AsyncStoreMutation do
  @moduledoc """
  Writes all AsyncStore records to a state.
  """

  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncStoreServer

  @derive AeMdw.Db.Mutation
  defstruct []

  @opaque t() :: %__MODULE__{}

  @spec new() :: t()
  def new() do
    %__MODULE__{}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{}, state) do
    AsyncStoreServer.write_async_store(state)
  end
end
