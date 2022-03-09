defprotocol AeMdw.Db.TxnMutation do
  @moduledoc """
  Same as AeMdw.Db.Mutation but using a known database transaction.
  """

  alias AeMdw.Db.State

  @doc """
  Abstracted function that performs the actual change into database.
  """
  @spec execute(t(), State.t()) :: State.t()
  def execute(mutation, state)
end

defimpl AeMdw.Db.TxnMutation, for: Any do
  def execute(%mod{} = mutation, state) do
    mod.execute(mutation, state)
  end
end
