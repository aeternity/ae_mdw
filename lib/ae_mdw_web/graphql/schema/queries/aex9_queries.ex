defmodule AeMdwWeb.GraphQL.Schema.Queries.Aex9Queries do
  use Absinthe.Schema.Notation

  @desc "AEX9 GraphQL queries"
  object :aex9_queries do
    @desc "AEX9 contracts count"
    field :aex9_count, :integer do
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_count/3)
    end

    @desc "List AEX9 contracts (paginated)"
    field :aex9_contracts, :aex9_contract_page do
      arg(:by, :string, description: "creation | name | symbol", default_value: "creation")
      arg(:prefix, :string)
      arg(:exact, :string)
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_contracts/3)
    end

    @desc "Fetch an AEX9 contract by id"
    field :aex9_contract, :aex9_contract do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_contract/3)
    end

    @desc "Balances within an AEX9 contract"
    field :aex9_contract_balances, :aex9_contract_balance_page do
      arg(:id, non_null(:string))
      arg(:order_by, :aex9_balance_order_by, default_value: :pubkey)
      arg(:block_hash, :string)
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 50)
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_contract_balances/3)
    end

    @desc "Single AEX9 balance for account on a contract"
    field :aex9_token_balance, :aex9_balance_history_item do
      # reuse fields: contract_id/account_id/amount (height may be null)
      arg(:contract_id, non_null(:string))
      arg(:account_id, non_null(:string))
      arg(:hash, :string, description: "Optional block hash to query balance at")
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_token_balance/3)
    end

    @desc "AEX9 balance history for an account on a contract"
    field :aex9_balance_history, :aex9_balance_history_item_page do
      arg(:contract_id, non_null(:string))
      arg(:account_id, non_null(:string))
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 50)
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_balance_history/3)
    end

    @desc "AEX9 transfers on a specific contract (filter by sender, recipient or account)"
    field :aex9_contract_transfers, :aex9_transfer_page do
      arg(:id, non_null(:string))
      arg(:sender, :string)
      arg(:recipient, :string)
      arg(:account, :string)
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 50)
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_contract_transfers/3)
    end

    @desc "AEX9 transfers sent by an account"
    field :aex9_transfers_from, :aex9_transfer_page do
      arg(:sender, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 50)
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_transfers_from/3)
    end

    @desc "AEX9 transfers received by an account"
    field :aex9_transfers_to, :aex9_transfer_page do
      arg(:recipient, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 50)
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_transfers_to/3)
    end

    @desc "AEX9 transfers from an account to another"
    field :aex9_transfers_pair, :aex9_transfer_page do
      arg(:sender, non_null(:string))
      arg(:recipient, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 50)
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_transfers_pair/3)
    end
  end
end
