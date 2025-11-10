defmodule AeMdwWeb.GraphQL.Resolvers.AccountResolver do
  alias AeMdw.Activities
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def activities(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

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
