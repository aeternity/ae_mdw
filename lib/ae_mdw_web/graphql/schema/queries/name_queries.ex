defmodule AeMdwWeb.GraphQL.Schema.Queries.NameQueries do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  object :name_queries do
    @desc "Fetch a single name or auction by plain name or name hash"
    field :name, :name do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name/3)
    end

    @desc "Fetch names"
    field :names, :name_page do
      arg(:order_by, :name_order, default_value: :expiration)
      arg(:owned_by, :string)
      arg(:prefix, :string)
      arg(:state, :name_state)
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.names/3)
    end

    @desc "Count names"
    field :names_count, :integer do
      arg(:owned_by, :string)
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.names_count/3)
    end

    @desc "Claims for a name"
    field :name_claims, :name_claim_page do
      arg(:id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name_claims/3)
    end

    @desc "Fetch name updates"
    field :name_updates, :name_update_page do
      arg(:id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name_updates/3)
    end

    @desc "Fetch name transfers"
    field :name_transfers, :name_transfer_page do
      arg(:id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name_transfers/3)
    end

    @desc "Fetch name history"
    field :name_history, :name_history_page do
      arg(:id, non_null(:string))
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name_history/3)
    end

    @desc "Fetch a single auction"
    field :auction, :auction do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.auction/3)
    end

    @desc "Fetch auctions"
    field :auctions, :auction_page do
      arg(:order_by, :auction_order, default_value: :expiration)
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.auctions/3)
    end

    @desc "Fetch auction claims"
    field :auction_claims, :name_claim_page do
      arg(:id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.auction_claims/3)
    end

    @desc "Fetch account name claims"
    field :account_name_claims, :name_claim_page do
      arg(:account_id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.account_name_claims/3)
    end

    @desc "Fetch account name pointees"
    field :account_name_pointees, :pointee_page do
      arg(:account_id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.account_name_pointees/3)
    end
  end
end
