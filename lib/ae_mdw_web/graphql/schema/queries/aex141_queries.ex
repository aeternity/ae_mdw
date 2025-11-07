defmodule AeMdwWeb.GraphQL.Schema.Queries.Aex141Queries do
  use Absinthe.Schema.Notation

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

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

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

      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_transfers/3)
    end

    # @desc "AEX141 transfers on a contract (filter by sender or recipient or none)"
    # field :aex141_contract_transfers, :aex141_transfer_page do
    #  arg(:id, non_null(:string))
    #  arg(:sender, :string)
    #  arg(:recipient, :string)
    #  arg(:cursor, :string)
    #  arg(:limit, :integer, default_value: 50)
    #  resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_contract_transfers/3)
    # end

    # @desc "Owners (tokens) of a contract"
    # field :aex141_contract_tokens, :aex141_token_owner_page do
    #  arg(:id, non_null(:string))
    #  arg(:cursor, :string)
    #  arg(:limit, :integer, default_value: 50)
    #  resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_contract_tokens/3)
    # end

    # @desc "Templates of a contract"
    # field :aex141_contract_templates, :aex141_template_page do
    #  arg(:id, non_null(:string))
    #  arg(:cursor, :string)
    #  arg(:limit, :integer, default_value: 50)
    #  resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_contract_templates/3)
    # end

    # @desc "Tokens minted for a template"
    # field :aex141_template_tokens, :aex141_template_token_page do
    #  arg(:id, non_null(:string))
    #  arg(:template_id, non_null(:integer))
    #  arg(:cursor, :string)
    #  arg(:limit, :integer, default_value: 50)
    #  resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_template_tokens/3)
    # end

    # @desc "Detailed NFT (owner + metadata)"
    # field :aex141_token_detail, :aex141_token_detail do
    #  arg(:contract_id, non_null(:string))
    #  arg(:token_id, non_null(:integer))
    #  resolve(&AeMdwWeb.GraphQL.Resolvers.Aex141Resolver.aex141_token_detail/3)
    # end
  end
end
