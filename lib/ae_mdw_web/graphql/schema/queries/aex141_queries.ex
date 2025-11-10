defmodule AeMdwWeb.GraphQL.Schema.Queries.Aex141Queries do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  object :aex141_queries do
    @desc "AEX141 contracts count"
    field :aex141_count, :integer do
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_count/3)
    end

    @desc "List AEX141 contracts"
    field :aex141_contracts, :aex141_contract_page do
      arg(:order_by, :aex141_contract_order_by, default_value: :creation)
      arg(:prefix, :string)
      arg(:exact, :string)
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_contracts/3)
    end

    @desc "Fetch an AEX141 contract by id"
    field :aex141_contract, :aex141_contract do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_contract/3)
    end

    @desc "Fetch AEX141 transfers"
    field :aex141_transfers, :aex141_transfer_page do
      arg(:sender, :string)
      arg(:recipient, :string)
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_transfers/3)
    end

    @desc "Fetch AEX141 transfers for a specific contract"
    field :aex141_contract_transfers, :aex141_transfer_page do
      arg(:contract_id, non_null(:string))
      arg(:from, :string)
      arg(:to, :string)
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_contract_transfers/3)
    end
  end
end
