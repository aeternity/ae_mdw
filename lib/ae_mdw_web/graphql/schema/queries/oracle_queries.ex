defmodule AeMdwWeb.GraphQL.Schema.Queries.OracleQueries do
  use Absinthe.Schema.Notation

  object :oracle_queries do
    @desc "Fetch an oracle by its public key"
    field :oracle, :oracle do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.OracleResolver.oracle/3)
    end

    @desc "Paginated oracles (backward by expiration); supports state filter and optional generation range"
    field :oracles, :oracle_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      arg(:state, :oracle_state, description: "Filter by oracle lifecycle state")
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      resolve(&AeMdwWeb.GraphQL.Resolvers.OracleResolver.oracles/3)
    end

    @desc "Oracle queries (questions addressed to the oracle)"
    field :oracle_queries, :oracle_query_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.OracleResolver.oracle_queries/3)
    end

    @desc "Oracle responses (answers provided by the oracle); supports optional generation range"
    field :oracle_responses, :oracle_response_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      resolve(&AeMdwWeb.GraphQL.Resolvers.OracleResolver.oracle_responses/3)
    end

    @desc "Oracle extends (extension transactions for the oracle)"
    field :oracle_extends, :oracle_extend_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.OracleResolver.oracle_extends/3)
    end
  end
end
