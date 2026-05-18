defmodule AeMdwWeb.GraphQL.Resolvers.TransferResolver do
  alias AeMdw.Transfers
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @spec transfers(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def transfers(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:account, :kind])

    Transfers.fetch_transfers(state, pagination, scope, query, cursor)
    |> Helpers.make_page()
  end
end
