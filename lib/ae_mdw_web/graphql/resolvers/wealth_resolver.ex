defmodule AeMdwWeb.GraphQL.Resolvers.WealthResolver do
  alias AeMdw.Wealth

  def wealth(_parent, _args, %{context: %{state: state}}) do
    {:ok,
     %{
       data: Wealth.fetch_balances(state)
     }}
  end
end
