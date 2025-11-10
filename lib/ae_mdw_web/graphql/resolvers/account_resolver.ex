defmodule AeMdwWeb.GraphQL.Resolvers.AccountResolver do
  alias AeMdw.Activities
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def activities(_p, %{id: id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}
    query = Helpers.maybe_put(query, "owned_only", Map.get(args, :owned_only))

    query =
      Helpers.maybe_put(
        query,
        "type",
        Map.get(args, :type) |> Helpers.maybe_map(&to_string/1)
      )

    Activities.fetch_account_activities(
      state,
      id,
      pagination,
      scope,
      query,
      cursor
    )
    |> Helpers.make_page()
  end
end
