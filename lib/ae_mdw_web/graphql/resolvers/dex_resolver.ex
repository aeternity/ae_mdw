defmodule AeMdwWeb.GraphQL.Resolvers.DexResolver do
  @moduledoc false

  alias AeMdw.Dex
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @spec swaps(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def swaps(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Helpers.make_page(Dex.fetch_swaps(state, pagination, scope, cursor))
  end

  @spec account_swaps(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def account_swaps(_parent, %{account_id: account_id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:token_symbol])

    Helpers.make_page(
      Dex.fetch_account_swaps(state, account_id, pagination, scope, cursor, query)
    )
  end

  @spec contract_swaps(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def contract_swaps(_parent, %{contract_id: contract_id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Helpers.make_page(Dex.fetch_contract_swaps(state, contract_id, pagination, scope, cursor))
  end
end
