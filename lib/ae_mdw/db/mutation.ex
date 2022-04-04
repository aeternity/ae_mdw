defprotocol AeMdw.Db.Mutation do
  @moduledoc """
  Database mutation abstraction to perform changes on the database.
  """

  @doc """
  Abstracted function that performs the actual change into database.
  """
  alias AeMdw.Db.State

  @spec execute(t(), State.t()) :: State.t()
  def execute(mutation, state)
end

defimpl AeMdw.Db.Mutation, for: Any do
  def execute(%mod{} = mutation, state) do
    mod.execute(mutation, state)
  end
end
