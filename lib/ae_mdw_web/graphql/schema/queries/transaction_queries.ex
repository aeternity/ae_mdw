defmodule AeMdwWeb.GraphQL.Schema.Queries.TransactionQueries do
  use Absinthe.Schema.Notation

  object :transaction_queries do
    @desc "Fetch a transaction by hash (or numeric index as string)"
    field :transaction, :transaction do
      arg(:id, non_null(:string), description: "Transaction hash or numeric index")
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transaction/3)
    end

    @desc "Count transactions (optionally filtered)"
    field :transactions_count, :integer do
      arg(:from_txi, :integer)
      arg(:to_txi, :integer)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      arg(:account, :string)
      arg(:type, :string)
      arg(:filter, :transaction_filter)
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transactions_count/3)
    end

    @desc "Paginated transactions (backward direction); minimal filters supported"
    field :transactions, :transaction_page do
      arg(:cursor, :string, description: "Opaque cursor (tx index)")
      arg(:limit, :integer, default_value: 20)
      # legacy txi range (still accepted)
      arg(:from_txi, :integer)
      arg(:to_txi, :integer)
      # new height based range
      arg(:from_height, :integer)
      arg(:to_height, :integer)
      arg(:account, :string, description: "Account public key filter")
      arg(:type, :string, description: "Transaction type filter (e.g. spend_tx)")

      arg(:filter, :transaction_filter,
        description: "Compound filter object {account,type,from_height,to_height}"
      )

      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transactions/3)
    end

    @desc "Transactions contained in a micro block"
    field :micro_block_transactions, :transaction_page do
      arg(:hash, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      arg(:account, :string)
      arg(:type, :string)
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.micro_block_transactions/3)
    end

    @desc "Pending transactions (node mempool)"
    field :pending_transactions, :transaction_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.pending_transactions/3)
    end

    @desc "Count of pending transactions (node mempool)"
    field :pending_transactions_count, :integer do
      resolve(&AeMdwWeb.GraphQL.Resolvers.TransactionResolver.pending_transactions_count/3)
    end
  end
end
