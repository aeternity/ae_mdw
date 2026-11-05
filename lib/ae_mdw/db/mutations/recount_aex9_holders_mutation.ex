defmodule AeMdw.Db.RecountAex9HoldersMutation do
  @moduledoc """
  Sets the holders count of an aex9 contract to the number of accounts with a
  positive balance.
  """

  alias AeMdw.Aex9
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Stats

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:contract_pk]

  @opaque t() :: %__MODULE__{contract_pk: Db.pubkey()}

  @spec new(Db.pubkey()) :: t()
  def new(contract_pk), do: %__MODULE__{contract_pk: contract_pk}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{contract_pk: contract_pk}, state) do
    holders_count = Aex9.fetch_holders_count(state, contract_pk)

    State.put(
      state,
      Model.Stat,
      Model.stat(index: Stats.aex9_holder_count_key(contract_pk), payload: holders_count)
    )
  end
end
