defmodule AeMdwWeb.GraphQL.Schema.Queries.AccountQueries do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  object :account_queries do
    @desc "Account activities"
    field :account_activities, :account_activity_page do
      arg(:id, non_null(:string))
      arg(:owned_only, :boolean)
      arg(:type, :activity_type)
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.AccountResolver.activities/3)
    end
  end
end
