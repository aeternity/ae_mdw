defmodule AeMdwWeb.GraphQL.Schema.Queries.TransactionQueries do
  use Absinthe.Schema.Notation

  object :transaction_queries do
    @desc "Get a single transaction"
    field :transaction, :transaction do
      arg(:hash, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transaction/3)
    end

    @desc "Pending transactions"
    field :pending_transactions, :transaction_page do
      # Pagination args
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.pending_transactions/3)
    end

    @desc "Count of pending transactions"
    field :pending_transactions_count, :integer do
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.pending_transactions_count/3)
    end

    # @desc "Total number of transactions"
    # field :transactions_count, :integer do
    #  arg(:from_txi, :integer)
    #  arg(:to_txi, :integer)
    #  arg(:from_height, :integer)
    #  arg(:to_height, :integer)
    #  arg(:account, :string)
    #  arg(:type, :string)
    #  arg(:filter, :transaction_filter)
    #  resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transactions_count/3)
    # end

    # @desc "Paginated transactions (backward direction); minimal filters supported"
    # field :transactions, :transaction_page do
    #  arg(:cursor, :string, description: "Opaque cursor (tx index)")
    #  arg(:limit, :integer, default_value: 20)
    #  # legacy txi range (still accepted)
    #  arg(:from_txi, :integer)
    #  arg(:to_txi, :integer)
    #  # new height based range
    #  arg(:from_height, :integer)
    #  arg(:to_height, :integer)
    #  arg(:account, :string, description: "Account public key filter")
    #  arg(:type, :string, description: "Transaction type filter (e.g. spend_tx)")

    #  arg(:filter, :transaction_filter,
    #    description: "Compound filter object {account,type,from_height,to_height}"
    #  )

    #  resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transactions/3)
    # end
  end
end
