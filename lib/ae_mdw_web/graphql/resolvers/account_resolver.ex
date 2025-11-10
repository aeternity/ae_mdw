defmodule AeMdwWeb.GraphQL.Resolvers.AccountResolver do
  alias AeMdw.Activities
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def activities(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:owned_only, :type])

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
