defmodule AeMdwWeb.GraphQL.Schema.Queries.ChannelQueries do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  object :channel_queries do
    @desc "Get multiple channels"
    field :channels, :channel_page do
      arg(:state, :channel_state)
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.ChannelResolver.channels/3)
    end

    @desc "Fetch a single channel"
    field :channel, :channel do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.ChannelResolver.channel/3)
    end

    @desc "Fetch all updates done to a channel"
    field :channel_updates, :channel_update_page do
      arg(:id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.ChannelResolver.channel_updates/3)
    end
  end
end
