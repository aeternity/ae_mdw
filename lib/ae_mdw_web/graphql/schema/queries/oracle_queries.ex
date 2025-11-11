defmodule AeMdwWeb.GraphQL.Schema.Queries.OracleQueries do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  object :oracle_queries do
    @desc "Get multiple oracles"
    field :oracles, :oracle_page do
      arg(:state, :oracle_state)
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.OracleResolver.oracles/3)
    end

    @desc "Fetch an oracle by its public key"
    field :oracle, :oracle do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.OracleResolver.oracle/3)
    end

    @desc "Get an oracle's queries"
    field :oracle_queries, :oracle_query_page do
      arg(:id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.OracleResolver.oracle_queries/3)
    end

    @desc "Get an oracle's responses"
    field :oracle_responses, :oracle_response_page do
      arg(:id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.OracleResolver.oracle_responses/3)
    end

    @desc "Get an oracle's extensions"
    field :oracle_extends, :oracle_extend_page do
      arg(:id, non_null(:string))
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.OracleResolver.oracle_extends/3)
    end
  end
end
