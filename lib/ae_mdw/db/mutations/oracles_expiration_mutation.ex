defmodule AeMdw.Db.OraclesExpirationMutation do
  @moduledoc """
  Deactivate all Oracles that have expired on a block height.

  The expiration height of an Oracle is always a result of the last `register`
   or `extend` operation.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Oracle
  alias AeMdw.Node.Db

  defstruct [:height, :expired_pubkeys]

  @opaque t() :: %__MODULE__{
            height: Blocks.height(),
            expired_pubkeys: [Db.pubkey()]
          }

  @spec new(Blocks.height(), [Db.pubkey()]) :: t()
  def new(height, expired_pubkeys) do
    %__MODULE__{height: height, expired_pubkeys: expired_pubkeys}
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{height: height, expired_pubkeys: expired_pubkeys}) do
    Enum.each(expired_pubkeys, &Oracle.expire_oracle(height, &1))
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.OraclesExpirationMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
