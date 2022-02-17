defprotocol AeMdw.Db.TxnMutation do
  @moduledoc """
  Same as AeMdw.Db.Mutation but using a known database transaction.
  """

  @doc """
  Abstracted function that performs the actual change into database.
  """
  @spec execute(AeMdw.Database.transaction(), t()) :: :ok
  def execute(transaction, mutation)
end
