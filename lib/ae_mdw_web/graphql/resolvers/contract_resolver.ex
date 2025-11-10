defmodule AeMdwWeb.GraphQL.Resolvers.ContractResolver do
  alias AeMdw.Contracts
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def contract(_p, %{id: id}, %{context: %{state: state}}) do
    Contracts.fetch_contract(state, id) |> Helpers.make_single()
  end

  def contracts(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Contracts.fetch_contracts(state, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def logs(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query =
      Helpers.build_query(args, [
        :contract_id,
        :event,
        :function,
        :function_prefix,
        :data,
        :aexn_args
      ])

    Contracts.fetch_logs(state, pagination, scope, query, cursor, v3?: true)
    |> Helpers.make_page()
  end

  def calls(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Contracts.fetch_calls(state, pagination, scope, [], cursor, v3?: true)
    |> Helpers.make_page()
  end

  def contract_logs(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query =
      Helpers.build_query(args, [
        :contract_id,
        :event,
        :function,
        :function_prefix,
        :data,
        :aexn_args
      ])

    Contracts.fetch_contract_logs(state, id, pagination, scope, query, cursor)
    |> Helpers.make_page()
  end

  def contract_calls(_p, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Contracts.fetch_contract_calls(state, id, pagination, scope, [], cursor)
    |> Helpers.make_page()
  end
end
