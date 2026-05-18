defmodule AeMdwWeb.GraphQL.Resolvers.OracleResolver do
  alias AeMdw.Oracles
  alias AeMdw.Db.State
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @spec oracle(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def oracle(_parent, %{id: id}, %{context: %{state: %State{} = state}}) do
    case AeMdw.Validate.id(id, [:oracle_pubkey]) do
      {:ok, pk} -> Oracles.fetch(state, pk, v3?: true) |> Helpers.make_single()
      {:error, err} -> {:error, Helpers.format_err(err)}
    end
  end

  @spec oracles(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def oracles(_parent, args, %{context: %{state: %State{} = state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:state])

    Oracles.fetch_oracles(state, pagination, scope, query, cursor, [{:v3?, true}])
    |> Helpers.make_page()
  end

  @spec oracle_queries(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def oracle_queries(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Oracles.fetch_oracle_queries(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  @spec oracle_responses(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def oracle_responses(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Oracles.fetch_oracle_responses(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  @spec oracle_extends(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def oracle_extends(_parent, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    Oracles.fetch_oracle_extends(state, id, pagination, cursor)
    |> Helpers.make_page()
  end
end
