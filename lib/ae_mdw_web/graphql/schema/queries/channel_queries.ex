defmodule AeMdwWeb.GraphQL.Schema.Queries.ChannelQueries do
  use Absinthe.Schema.Notation

  object :channel_queries do
    @desc "Get multiple channels"
    field :channels, :channel_page do
      arg(:state, :channel_state)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)
      arg(:from_height, :integer)
      arg(:to_height, :integer)

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

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)
      arg(:from_height, :integer)
      arg(:to_height, :integer)

      resolve(&AeMdwWeb.GraphQL.Resolvers.ChannelResolver.channel_updates/3)
    end
  end
end
