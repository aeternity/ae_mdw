defmodule AeMdwWeb.GraphQL.Resolvers.AccountResolver do
  alias AeMdw.Activities
  alias AeMdw.Validate
  alias AeMdw.Db.{State, Model}
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  require Model

  @spec account(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def account(_parent, %{id: id}, %{context: %{state: state}}) do
    case Validate.id(id) do
      {:ok, pubkey} ->
        case State.get(state, Model.AccountBalance, pubkey) do
          {:ok, Model.account_balance(balance: balance)} ->
            {:ok, %{id: id, balance: balance, creation_time: nil}}

          :not_found ->
            {:error, "account_not_found"}
        end

      {:error, _} ->
        {:error, "account_not_found"}
    end
  end

  def account(_parent, _args, _resolution), do: {:error, "partial_state_unavailable"}

  @spec activities(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def activities(_parent, %{id: id} = args, %{context: %{state: state}}) do
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
