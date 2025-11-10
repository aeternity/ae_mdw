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

    @desc "Pending transactions"
    field :pending_transactions, :transaction_page do
      Macros.pagination_args()
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.pending_transactions/3)
    end

    @desc "Count of pending transactions"
    field :pending_transactions_count, :integer do
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.pending_transactions_count/3)
    end
  end
end
