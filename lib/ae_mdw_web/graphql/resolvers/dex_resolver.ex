defmodule AeMdwWeb.GraphQL.Resolvers.DexResolver do
  alias AeMdw.Dex
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def swaps(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Dex.fetch_swaps(state, pagination, scope, cursor) |> Helpers.make_page()
  end

  def account_swaps(_p, %{account_id: account_id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}

    query =
      Helpers.maybe_put(
        query,
        "token_symbol",
        Map.get(args, :token_symbol)
      )

    Dex.fetch_account_swaps(state, account_id, pagination, scope, cursor, query)
    |> Helpers.make_page()
  end

  def contract_swaps(_p, %{contract_id: contract_id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Dex.fetch_contract_swaps(state, contract_id, pagination, scope, cursor)
    |> Helpers.make_page()
  end
end
