defmodule AeMdwWeb.GraphQL.Schema.Queries.TransferQueries do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  object :transfer_queries do
    @desc "Get transfers with optional filters"
    field :transfers, :transfer_page do
      arg(:account, :string)
      arg(:kind, :string)
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransferResolver.transfers/3)
    end
  end
end
