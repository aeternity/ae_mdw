defmodule AeMdwWeb.GraphQL.Schema.Queries.StatsQueries do
  use Absinthe.Schema.Notation

  object :stat_queries do
    @desc "Statistics over time of transactions count"
    field :transactions_stats, :start_end_count_stats_page do
      arg(:tx_type, :string)

      arg(:interval_by, :stats_interval, default_value: :day)
      arg(:min_start_date, :string)
      arg(:max_start_date, :string)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.transactions/3)
    end

    @desc "Count of transactions count over time"
    field :total_transactions_stats, :integer do
      arg(:tx_type, :string)

      arg(:min_start_date, :string)
      arg(:max_start_date, :string)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.transactions_total/3)
    end

    @desc "Statistics over time of blocks count"
    field :blocks_stats, :start_end_count_stats_page do
      arg(:type, :block_type)

      arg(:interval_by, :stats_interval, default_value: :day)
      arg(:min_start_date, :string)
      arg(:max_start_date, :string)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.blocks/3)
    end

    @desc "Statistics over time of difficulty"
    field :difficulty_stats, :start_end_count_stats_page do
      arg(:interval_by, :stats_interval, default_value: :day)
      arg(:min_start_date, :string)
      arg(:max_start_date, :string)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.difficulty/3)
    end

    @desc "Statistics over time of hashrate"
    field :hashrate_stats, :start_end_count_stats_page do
      arg(:interval_by, :stats_interval, default_value: :day)
      arg(:min_start_date, :string)
      arg(:max_start_date, :string)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.hashrate/3)
    end

    @desc "Statistics over time of total accounts count"
    field :total_accounts_stats, :start_end_count_stats_page do
      arg(:interval_by, :stats_interval, default_value: :day)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.total_accounts/3)
    end

    @desc "Statistics over time of active accounts count"
    field :active_accounts_stats, :start_end_count_stats_page do
      arg(:interval_by, :stats_interval, default_value: :day)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.active_accounts/3)
    end

    @desc "Statistics over time of names count"
    field :names_stats, :start_end_count_stats_page do
      arg(:interval_by, :stats_interval, default_value: :day)
      arg(:min_start_date, :string)
      arg(:max_start_date, :string)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.names/3)
    end

    @desc "Statistics for generations from tip of the chain"
    field :total_stats, :total_stats_page do
      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.total/3)
    end

    @desc "Aggregated statistics for generations from tip of the chain"
    field :delta_stats, :delta_stats_page do
      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.delta/3)
    end

    @desc "Statistics over time of contracts count"
    field :contracts_stats, :start_end_count_stats_page do
      arg(:interval_by, :stats_interval, default_value: :day)
      arg(:min_start_date, :string)
      arg(:max_start_date, :string)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.contracts/3)
    end

    @desc "Statistics over time of AEX9 transfers count"
    field :aex9_transfers_stats, :start_end_count_stats_page do
      arg(:interval_by, :stats_interval, default_value: :day)
      arg(:min_start_date, :string)
      arg(:max_start_date, :string)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.aex9_transfers/3)
    end

    @desc "Global statistics"
    field :stats, :stats do
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.stats/3)
    end

    @desc "Total rewards for each miner"
    field :miners_stats, :miners_stats_page do
      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.miners/3)
    end

    @desc "Top miners statistics"
    field :top_miners_stats, :top_miners_stats_page do
      arg(:interval_by, :stats_interval, default_value: :day)
      arg(:min_start_date, :string)
      arg(:max_start_date, :string)

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.top_miners/3)
    end

    @desc "Top miners in the last 24 hours statistics"
    field :top_miners_24h_stats, :top_miners_24h_stats_page do
      resolve(&AeMdwWeb.GraphQL.Resolvers.StatsResolver.top_miners_24h/3)
    end
  end
end
