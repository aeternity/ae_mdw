defmodule AeMdwWeb.GraphQL.Resolvers.ContractResolver do
  alias AeMdw.Contracts
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def contract(_p, %{id: id}, %{context: %{state: state}}) do
    Contracts.fetch_contract(state, id) |> Helpers.make_single()
  end

  def contracts(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Contracts.fetch_contracts(state, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def logs(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}
    query = Helpers.maybe_put(query, "contract_id", Map.get(args, :contract_id))
    query = Helpers.maybe_put(query, "event", Map.get(args, :event))
    query = Helpers.maybe_put(query, "function", Map.get(args, :function))
    query = Helpers.maybe_put(query, "function_prefix", Map.get(args, :function_prefix))
    query = Helpers.maybe_put(query, "data", Map.get(args, :data))
    query = Helpers.maybe_put(query, "aexn_args", Map.get(args, :aexn_args))

    Contracts.fetch_logs(state, pagination, scope, query, cursor, v3?: true)
    |> Helpers.make_page()
  end

  def calls(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Contracts.fetch_calls(state, pagination, scope, [], cursor, v3?: true)
    |> Helpers.make_page()
  end

  def contract_logs(_p, %{id: id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}
    query = Helpers.maybe_put(query, "contract_id", Map.get(args, :contract_id))
    query = Helpers.maybe_put(query, "event", Map.get(args, :event))
    query = Helpers.maybe_put(query, "function", Map.get(args, :function))
    query = Helpers.maybe_put(query, "function_prefix", Map.get(args, :function_prefix))
    query = Helpers.maybe_put(query, "data", Map.get(args, :data))
    query = Helpers.maybe_put(query, "aexn_args", Map.get(args, :aexn_args))

    Contracts.fetch_contract_logs(state, id, pagination, scope, query, cursor)
    |> Helpers.make_page()
  end

  def contract_calls(_p, %{id: id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Contracts.fetch_contract_calls(state, id, pagination, scope, [], cursor)
    |> Helpers.make_page()
  end
end
