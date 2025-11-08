defmodule AeMdwWeb.GraphQL.Resolvers.ContractResolver do
  alias AeMdw.Contracts
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def contract(_p, %{id: id}, %{context: %{state: state}}) do
    case Contracts.fetch_contract(state, id) do
      {:ok, contract} -> {:ok, contract |> Helpers.normalize_map()}
      {:error, err} -> {:error, ErrInput.message(err)}
    end
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

    case Contracts.fetch_contracts(state, pagination, scope, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: items |> Enum.map(&Helpers.normalize_map/1)
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
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

    case Contracts.fetch_logs(state, pagination, scope, query, cursor, v3?: true) do
      {:ok, {prev, items, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: items |> Enum.map(&Helpers.normalize_map/1)
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
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

    case Contracts.fetch_calls(state, pagination, scope, [], cursor, v3?: true) do
      {:ok, {prev, items, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: items |> Enum.map(&Helpers.normalize_map/1)
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
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

    case Contracts.fetch_contract_logs(state, id, pagination, scope, query, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: items |> Enum.map(&Helpers.normalize_map/1)
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
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

    case Contracts.fetch_contract_calls(state, id, pagination, scope, [], cursor) do
      {:ok, {prev, items, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: items |> Enum.map(&Helpers.normalize_map/1)
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end
end
