defmodule AeMdwWeb.GraphQL.Schema.Queries.WealthQueries do
  use Absinthe.Schema.Notation

  object :wealth_queries do
    @desc "Get wealth distribution (top accounts by balance)"
    field :wealth, :wealth_page do
      resolve(&AeMdwWeb.GraphQL.Resolvers.WealthResolver.wealth/3)
    end
  end
end
