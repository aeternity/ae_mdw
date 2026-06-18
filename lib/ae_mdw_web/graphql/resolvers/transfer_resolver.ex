defmodule AeMdwWeb.GraphQL.Resolvers.TransferResolver do
  @moduledoc false

  alias AeMdw.Transfers
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @spec transfers(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def transfers(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:account, :kind])

    Helpers.make_page(Transfers.fetch_transfers(state, pagination, scope, query, cursor))
  end
end
