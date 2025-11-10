defmodule AeMdwWeb.GraphQL.Schema.Queries.Aex9Queries do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  object :aex9_queries do
    @desc "AEX9 contracts count"
    field :aex9_count, :integer do
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_count/3)
    end

    @desc "Get AEX9 tokens sorted by creation time, name or symbol"
    field :aex9_contracts, :aex9_contract_page do
      arg(:order_by, :aex9_contract_order_by, default_value: :creation)
      arg(:prefix, :string)
      arg(:exact, :string)
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_contracts/3)
    end

    @desc "Fetch an AEX9 creation and meta_info information by contract id"
    field :aex9_contract, :aex9_contract do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_contract/3)
    end

    @desc "Balances within an AEX9 contract"
    field :aex9_contract_balances, :aex9_contract_balance_page do
      arg(:id, non_null(:string))
      arg(:order_by, :aex9_balance_order_by, default_value: :pubkey)
      arg(:block_hash, :string)
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_contract_balances/3)
    end

    @desc "AEX9 balance history for an account on a contract"
    field :aex9_balance_history, :aex9_balance_history_item_page do
      arg(:contract_id, non_null(:string))
      arg(:account_id, non_null(:string))
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_balance_history/3)
    end

    @desc "Get AEX9 token balance for a specific account on a contract"
    field :aex9_token_balance, :aex9_balance do
      arg(:contract_id, non_null(:string))
      arg(:account_id, non_null(:string))
      arg(:hash, :string)
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_token_balance/3)
    end

    @desc "Get all AEX9 token balances for an account"
    field :aex9_account_balances, :aex9_account_balance_page do
      arg(:account_id, non_null(:string))
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_account_balances/3)
    end

    @desc "Fetch AEX9 transfers for a specific contract"
    field :aex9_contract_transfers, :aex9_transfer_page do
      arg(:contract_id, non_null(:string))
      arg(:sender, :string)
      arg(:recipient, :string)
      arg(:account, :string)
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.Aex9Resolver.aex9_contract_transfers/3)
    end
  end
end
