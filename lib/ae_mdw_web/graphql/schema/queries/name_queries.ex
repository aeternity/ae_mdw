defmodule AeMdwWeb.GraphQL.Schema.Queries.NameQueries do
  use Absinthe.Schema.Notation

  object :name_queries do
    @desc "Paginated names (initial release). Supports filters owned_by, state, prefix and order_by"
    field :names, :name_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      arg(:order_by, :name_order, default_value: :expiration)
      arg(:owned_by, :string)
      arg(:state, :name_state)
      arg(:prefix, :string)
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.names/3)
    end

    @desc "Count names (filters owned_by, state, prefix)"
    field :names_count, :integer do
      arg(:owned_by, :string)
      arg(:state, :name_state)
      arg(:prefix, :string)
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.names_count/3)
    end

    @desc "Fetch a single name or auction by plain name or name hash"
    field :name, :name do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name/3)
    end

    @desc "History for a name (claims, updates, transfers, revoke, expire)"
    field :name_history, :name_history_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name_history/3)
    end

    @desc "Claims for a name"
    field :name_claims, :name_history_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name_claims/3)
    end

    @desc "Updates for a name"
    field :name_updates, :name_history_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name_updates/3)
    end

    @desc "Transfers for a name"
    field :name_transfers, :name_history_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name_transfers/3)
    end

    @desc "Fetch a single auction"
    field :auction, :auction do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.auction/3)
    end

    @desc "Paginated auctions"
    field :auctions, :auction_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      arg(:order_by, :auction_order, default_value: :expiration)
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.auctions/3)
    end

    @desc "Search names & auctions (only supports prefix + optional lifecycle filters)"
    field :search_names, :search_name_page do
      arg(:prefix, :string)
      arg(:only, list_of(:string), description: "Allowed values: active, inactive, auction")
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.search_names/3)
    end

    @desc "Account pointees (names pointing to account via AENS pointers)"
    field :account_pointees, :pointee_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.account_pointees/3)
    end

    @desc "Name pointees (active & inactive pointer entries for a given name hash)"
    field :name_pointees, :name_pointees do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.NameResolver.name_pointees/3)
    end
  end
end
