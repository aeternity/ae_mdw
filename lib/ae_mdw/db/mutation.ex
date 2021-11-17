defprotocol AeMdw.Db.Mutation do
  @moduledoc """
  Protocol aimed at specifying all database mutations declaratively. This can be
  a simple write to mnesia, or more complex logic involving multiple mnesia
  queries or calls to other services.

  The goal of this protocol is to do as much work as possible before starting
  the mnesia transaction. Once the mnesia transaction is started, the mutate
  function is called for every mutation generated.
  """

  @doc """
  Abstracted function that performs the actual mutation into the mnesia database.
  """
  @spec mutate(t()) :: :ok
  def mutate(mutation)
end
