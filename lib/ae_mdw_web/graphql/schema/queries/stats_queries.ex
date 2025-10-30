defmodule AeMdwWeb.GraphQL.Schema.Queries.StatsQueries do
  use Absinthe.Schema.Notation

  object :stat_queries do
    @desc "Statistics for generations from tip of the chain"
    field :total_stats, :total_stats_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.total/3)
    end

    @desc "Aggregated statistics for generations from tip of the chain"
    field :delta_stats, :delta_stats_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.delta/3)
    end

    @desc "Total rewards for each miner"
    field :miners_stats, :miners_stats_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.miners/3)
    end

    @desc "Statistics over time of transactions count"
    field :transactions_stats, :transactions_stats_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.transactions/3)
    end

    @desc "Statistics over time of blocks count"
    field :blocks_stats, :blocks_stats_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.blocks/3)
    end

    @desc "Statistics over time of names count"
    field :names_stats, :blocks_stats_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 10)
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.names/3)
    end

    @desc "Global statistics"
    field :stats, :stats do
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.stats/3)
    end
  end
end
