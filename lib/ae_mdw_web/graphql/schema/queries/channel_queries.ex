defmodule AeMdwWeb.GraphQL.Schema.Queries.ChannelQueries do
  use Absinthe.Schema.Notation

  object :channel_queries do
    @desc "Paginated channels; supports state filter and optional generation range"
    field :channels, :channel_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      arg(:state, :channel_state)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      resolve(&AeMdwWeb.GraphQL.Resolvers.ChannelResolver.channels/3)
    end

    @desc "Fetch a single channel by id; optionally at a specific block hash"
    field :channel, :channel do
      arg(:id, non_null(:string))
      arg(:block_hash, :string, description: "Key-block hash (kh_*) or micro-block hash (mh_*)")
      resolve(&AeMdwWeb.GraphQL.Resolvers.ChannelResolver.channel/3)
    end

    @desc "Channel updates (nested transactions)"
    field :channel_updates, :channel_update_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      resolve(&AeMdwWeb.GraphQL.Resolvers.ChannelResolver.channel_updates/3)
    end
  end
end
