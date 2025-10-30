defmodule AeMdwWeb.GraphQL.Schema.Queries.AccountQueries do
  use Absinthe.Schema.Notation

  object :account_queries do
    @desc "Fetch an account by its public key"
    field :account, :account do
      arg(:id, non_null(:string))
      resolve(&AeMdwWeb.GraphQL.Resolvers.AccountResolver.account/3)
    end

    @desc "Paginated accounts (backward by pubkey); only nextCursor supported for now"
    field :accounts, :account_page do
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.AccountResolver.accounts/3)
    end

    @desc "Names owned by an account"
    field :account_names, :name_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 20)
      resolve(&AeMdwWeb.GraphQL.Resolvers.AccountResolver.account_names/3)
    end

    @desc "AEX9 token balances for an account"
    field :account_aex9_balances, :aex9_balance_page do
      arg(:id, non_null(:string))
      arg(:cursor, :string)
      arg(:limit, :integer, default_value: 50)
      resolve(&AeMdwWeb.GraphQL.Resolvers.AccountResolver.account_aex9_balances/3)
    end
  end
end
