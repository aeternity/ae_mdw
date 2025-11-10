defmodule AeMdwWeb.GraphQL.Resolvers.OracleResolver do
  alias AeMdw.Oracles
  alias AeMdw.Db.State
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def oracle(_p, %{id: id}, %{context: %{state: %State{} = state}}) do
    with {:ok, pk} <- AeMdw.Validate.id(id, [:oracle_pubkey]) do
      Oracles.fetch(state, pk, v3?: true) |> Helpers.make_single()
    else
      {:error, err} -> {:error, Helpers.format_err(err)}
    end
  end

  def oracles(_p, args, %{context: %{state: %State{} = state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:state])

    Oracles.fetch_oracles(state, pagination, scope, query, cursor, [{:v3?, true}])
    |> Helpers.make_page()
  end

  def oracle_queries(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Oracles.fetch_oracle_queries(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def oracle_responses(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Oracles.fetch_oracle_responses(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def oracle_extends(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    Oracles.fetch_oracle_extends(state, id, pagination, cursor)
    |> Helpers.make_page()
  end
end
