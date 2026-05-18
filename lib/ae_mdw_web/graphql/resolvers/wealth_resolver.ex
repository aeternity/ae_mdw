defmodule AeMdwWeb.GraphQL.Resolvers.WealthResolver do
  alias AeMdw.Wealth

  @spec wealth(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def wealth(_parent, _args, %{context: %{state: state}}) do
    {:ok,
     %{
       data: Wealth.fetch_balances(state)
     }}
  end
end
