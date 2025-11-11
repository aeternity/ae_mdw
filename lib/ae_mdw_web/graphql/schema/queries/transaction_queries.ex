defmodule AeMdwWeb.GraphQL.Schema.Queries.TransactionQueries do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  object :transaction_queries do
    @desc "Get a single transaction"
    field :transaction, :transaction do
      arg(:hash, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transaction/3)
    end

    @desc "Get transactions with optional filters"
    field :transactions, :transaction_page do
      arg(:type, list_of(:string))
      arg(:type_group, list_of(:string))
      arg(:account, :string)
      arg(:contract, :string)
      arg(:channel, :string)
      arg(:oracle, :string)
      arg(:sender_id, :string)
      arg(:recipient_id, :string)
      arg(:entrypoint, :string)
      Macros.pagination_args_with_scope()
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transactions/3)
    end

    @desc "Pending transactions"
    field :pending_transactions, :transaction_page do
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.pending_transactions/3)
    end

    @desc "Count of pending transactions"
    field :pending_transactions_count, :integer do
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.pending_transactions_count/3)
    end

    @desc "Count transactions with optional filters"
    field :transactions_count, :integer do
      arg(:id, :string)
      arg(:type, :string)
      arg(:type_group, :string)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transactions_count/3)
    end

    @desc "Get transactions from a micro block"
    field :micro_block_transactions, :transaction_page do
      arg(:hash, non_null(:string))
      arg(:type, list_of(:string))
      arg(:type_group, list_of(:string))
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.micro_block_transactions/3)
    end

    @desc "Get detailed transaction counts for an account"
    field :account_transactions_count, :json do
      arg(:id, non_null(:string))
      arg(:type, :string)
      arg(:type_group, :string)
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.account_transactions_count/3)
    end
  end
end
