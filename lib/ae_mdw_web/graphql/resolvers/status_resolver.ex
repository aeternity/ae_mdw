defmodule AeMdwWeb.GraphQL.Resolvers.StatusResolver do
  alias AeMdw.Db.Status

  def status(_p, _args, %{context: %{state: state}}) do
    {:ok, Status.node_and_mdw_status(state)}
  end
end
