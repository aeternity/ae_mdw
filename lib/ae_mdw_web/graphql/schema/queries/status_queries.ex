defmodule AeMdwWeb.GraphQL.Schema.Queries.StatusQueries do
  use Absinthe.Schema.Notation

  object :status_queries do
    @desc "Get middleware status"
    field :status, :status do
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatusResolver.status/3)
    end

    @desc "Get sync status"
    field :sync_status, :sync_status do
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatusResolver.sync_status/3)
    end
  end
end
