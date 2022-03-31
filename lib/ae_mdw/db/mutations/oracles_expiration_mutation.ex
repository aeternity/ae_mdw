defmodule AeMdw.Db.OraclesExpirationMutation do
  @moduledoc """
  Deactivate all Oracles that have expired on a block height.

  The expiration height of an Oracle is always a result of the last `register`
   or `extend` operation.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle

  @derive AeMdw.Db.TxnMutation
  defstruct [:height]

  @opaque t() :: %__MODULE__{
            height: Blocks.height()
          }

  @spec new(Blocks.height()) :: t()
  def new(height), do: %__MODULE__{height: height}

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(%__MODULE__{height: height}, txn) do
    Model.ActiveOracleExpiration
    |> Collection.stream({height, <<>>})
    |> Stream.take_while(&match?({^height, _pk}, &1))
    |> Enum.each(fn {^height, pubkey} -> Oracle.expire_oracle(txn, height, pubkey) end)
  end
end
