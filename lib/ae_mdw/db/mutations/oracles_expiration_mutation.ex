defmodule AeMdw.Db.OraclesExpirationMutation do
  @moduledoc """
  Deactivate all Oracles that have expired on a block height.

  The expiration height of an Oracle is always a result of the last `register`
   or `extend` operation.
  """

  alias AeMdw.Blocks
  alias AeMdw.Database
  alias AeMdw.Db.Oracle
  alias AeMdw.Node.Db

  @derive AeMdw.Db.TxnMutation
  defstruct [:height, :expired_pubkeys]

  @opaque t() :: %__MODULE__{
            height: Blocks.height(),
            expired_pubkeys: [Db.pubkey()]
          }

  @spec new(Blocks.height(), [Db.pubkey()]) :: t()
  def new(height, expired_pubkeys) do
    %__MODULE__{height: height, expired_pubkeys: expired_pubkeys}
  end

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(%__MODULE__{height: height, expired_pubkeys: expired_pubkeys}, txn) do
    Enum.each(expired_pubkeys, &Oracle.expire_oracle(txn, height, &1))
  end
end
