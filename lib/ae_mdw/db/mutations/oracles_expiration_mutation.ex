defmodule AeMdw.Db.OraclesExpirationMutation do
  @moduledoc """
  Deactivate all Oracles that have expired on a block height.

  The expiration height of an Oracle is always a result of the last `register`
   or `extend` operation.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.State

  @derive AeMdw.Db.Mutation
  defstruct [:height]

  @opaque t() :: %__MODULE__{
            height: Blocks.height()
          }

  @spec new(Blocks.height()) :: t()
  def new(height), do: %__MODULE__{height: height}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{height: height}, state) do
    state
    |> Collection.stream(Model.ActiveOracleExpiration, {height, <<>>})
    |> Stream.take_while(&match?({^height, _pk}, &1))
    |> Enum.to_list()
    |> Enum.reduce(state, fn {^height, pubkey}, state ->
      Oracle.expire_oracle(state, height, pubkey)
    end)
  end
end
