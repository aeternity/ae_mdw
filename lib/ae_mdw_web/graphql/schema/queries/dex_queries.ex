defmodule AeMdwWeb.GraphQL.Schema.Queries.DexQueries do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  object :dex_queries do
    @desc "Get all DEX swaps"
    field :swaps, :swap_page do
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.DexResolver.swaps/3)
    end

    @desc "Get DEX swaps for a specific account"
    field :account_swaps, :swap_page do
      arg(:account_id, non_null(:string))
      arg(:token_symbol, :string)
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.DexResolver.account_swaps/3)
    end

    @desc "Get DEX swaps for a specific contract"
    field :contract_swaps, :swap_page do
      arg(:contract_id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.DexResolver.contract_swaps/3)
    end
  end
end
