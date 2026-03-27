defmodule AeMdwWeb.GraphQL.Resolvers.DexResolver do
  alias AeMdw.Dex
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def swaps(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Dex.fetch_swaps(state, pagination, scope, cursor) |> Helpers.make_page()
  end

  def account_swaps(_p, %{account_id: account_id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:token_symbol])

    Dex.fetch_account_swaps(state, account_id, pagination, scope, cursor, query)
    |> Helpers.make_page()
  end

  def contract_swaps(_p, %{contract_id: contract_id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Dex.fetch_contract_swaps(state, contract_id, pagination, scope, cursor)
    |> Helpers.make_page()
  end
end
