defmodule AeMdwWeb.GraphQL.Schema.Queries.MinerStatsQueries do
  @moduledoc false

  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Resolvers.MinerStatsResolver
  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  object :miner_stats_queries do
    @desc "Mining totals and how far the stats have been built from the finalized generations"
    field :mining_summary, :mining_summary do
      resolve(&MinerStatsResolver.summary/3)
    end

    @desc "Miners (by key or by beneficiary) sorted by one of their totals or activity"
    field :miners, :miner_entity_page do
      arg(:role, :miner_role)
      arg(:order_by, :miners_order)

      Macros.pagination_args()

      resolve(&MinerStatsResolver.miners/3)
    end

    @desc "A miner (by key or by beneficiary)"
    field :miner, :miner_entity do
      arg(:id, non_null(:string))
      arg(:role, :miner_role)

      resolve(&MinerStatsResolver.miner/3)
    end

    @desc "The beneficiaries of a miner key or the miner keys of a beneficiary"
    field :miner_links, :miner_link_page do
      arg(:id, non_null(:string))
      arg(:role, :miner_role)

      Macros.pagination_args()

      resolve(&MinerStatsResolver.links/3)
    end

    @desc "Series of a miner, bucketed by the generations it mined in"
    field :miner_series, :miner_series_row_page do
      arg(:id, non_null(:string))
      arg(:role, :miner_role)
      arg(:interval, :integer)
      arg(:interval_by, :stats_interval)

      Macros.pagination_args_with_scope()

      resolve(&MinerStatsResolver.miner_series/3)
    end

    @desc "Series of the mining of the whole network"
    field :mining_series, :mining_series_row_page do
      arg(:interval, :integer)
      arg(:interval_by, :stats_interval)

      Macros.pagination_args_with_scope()

      resolve(&MinerStatsResolver.mining_series/3)
    end

    @desc "A bucket of the mining series"
    field :mining_bucket, :mining_series_row do
      arg(:bucket, non_null(:integer))

      resolve(&MinerStatsResolver.bucket/3)
    end

    @desc "The miners that mined in a bucket"
    field :mining_bucket_miners, :miner_series_row_page do
      arg(:bucket, non_null(:integer))
      arg(:role, :miner_role)

      Macros.pagination_args()

      resolve(&MinerStatsResolver.bucket_miners/3)
    end
  end
end
