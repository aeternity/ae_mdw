defprotocol AeMdw.Db.TxnMutation do
  @moduledoc """
  Same as AeMdw.Db.Mutation but using a known database transaction.
  """

  @doc """
  Abstracted function that performs the actual change into database.
  """
  @spec execute(t(), AeMdw.Database.transaction()) :: :ok
  def execute(mutation, transaction)
end

defimpl AeMdw.Db.TxnMutation, for: Any do
  def execute(%mod{} = mutation, txn) do
    mod.execute(mutation, txn)
  end
end
