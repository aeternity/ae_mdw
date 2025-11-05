defmodule AeMdwWeb.GraphQL.Resolvers.ContractResolver do
  @moduledoc """
  Contract resolvers: contract list, single contract, logs (global and by contract), and calls (global and by contract).
  """
  alias AeMdw.{Contracts}
  alias AeMdw.Db.State
  alias AeMdw.Error.Input, as: ErrInput

  @max_limit 100

  def contract(_p, %{id: id}, %{context: %{state: %State{} = state}}) do
    case Contracts.fetch_contract(state, id) do
      {:ok, contract} -> {:ok, contract}
      {:error, %ErrInput.NotFound{}} -> {:error, "contract_not_found"}
      {:error, _} -> {:error, "contract_error"}
    end
  end

  def contract(_, _args, _), do: {:error, "partial_state_unavailable"}

  def contracts(_p, args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)

    range =
      cond do
        from_h && to_h -> {:gen, from_h..to_h}
        to_h && is_nil(from_h) -> {:gen, 0..to_h}
        from_h && is_nil(to_h) -> {:gen, from_h..from_h}
        true -> nil
      end

    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Contracts.fetch_contracts(state, pagination, range, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}

      {:error, %ErrInput.Cursor{}} ->
        {:error, "invalid_cursor"}

      {:error, %ErrInput.Scope{}} ->
        {:error, "invalid_scope"}

      {:error, _} ->
        {:error, "contracts_error"}
    end
  end

  def contracts(_, _args, _), do: {:error, "partial_state_unavailable"}

  def logs(_p, args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)

    range =
      cond do
        from_h && to_h -> {:gen, from_h..to_h}
        to_h && is_nil(from_h) -> {:gen, 0..to_h}
        from_h && is_nil(to_h) -> {:gen, from_h..from_h}
        true -> nil
      end

    query = build_logs_query(args)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Contracts.fetch_logs(state, pagination, range, query, cursor, v3?: true) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}

      {:error, %ErrInput.Cursor{}} ->
        {:error, "invalid_cursor"}

      {:error, %ErrInput.Scope{}} ->
        {:error, "invalid_scope"}

      {:error, %ErrInput.Query{}} ->
        {:error, "invalid_filter"}

      {:error, _} ->
        {:error, "contract_logs_error"}
    end
  end

  def logs(_, _args, _), do: {:error, "partial_state_unavailable"}

  def contract_logs(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)

    range =
      cond do
        from_h && to_h -> {:gen, from_h..to_h}
        to_h && is_nil(from_h) -> {:gen, 0..to_h}
        from_h && is_nil(to_h) -> {:gen, from_h..from_h}
        true -> nil
      end

    query = build_logs_query(args)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Contracts.fetch_contract_logs(state, id, pagination, range, query, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}

      {:error, %ErrInput.Cursor{}} ->
        {:error, "invalid_cursor"}

      {:error, %ErrInput.Scope{}} ->
        {:error, "invalid_scope"}

      {:error, %ErrInput.NotFound{}} ->
        {:error, "contract_not_found"}

      {:error, %ErrInput.Query{}} ->
        {:error, "invalid_filter"}

      {:error, _} ->
        {:error, "contract_logs_error"}
    end
  end

  def contract_logs(_, _args, _), do: {:error, "partial_state_unavailable"}

  def calls(_p, args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)

    range =
      cond do
        from_h && to_h -> {:gen, from_h..to_h}
        to_h && is_nil(from_h) -> {:gen, 0..to_h}
        from_h && is_nil(to_h) -> {:gen, from_h..from_h}
        true -> nil
      end

    query = build_calls_query(args)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Contracts.fetch_calls(state, pagination, range, query, cursor, v3?: true) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}

      {:error, %ErrInput.Cursor{}} ->
        {:error, "invalid_cursor"}

      {:error, %ErrInput.Scope{}} ->
        {:error, "invalid_scope"}

      {:error, %ErrInput.Query{}} ->
        {:error, "invalid_filter"}

      {:error, _} ->
        {:error, "contract_calls_error"}
    end
  end

  def calls(_, _args, _), do: {:error, "partial_state_unavailable"}

  def contract_calls(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)

    range =
      cond do
        from_h && to_h -> {:gen, from_h..to_h}
        to_h && is_nil(from_h) -> {:gen, 0..to_h}
        from_h && is_nil(to_h) -> {:gen, from_h..from_h}
        true -> nil
      end

    query = build_calls_query(args)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Contracts.fetch_contract_calls(state, id, pagination, range, query, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}

      {:error, %ErrInput.Cursor{}} ->
        {:error, "invalid_cursor"}

      {:error, %ErrInput.Scope{}} ->
        {:error, "invalid_scope"}

      {:error, %ErrInput.NotFound{}} ->
        {:error, "contract_not_found"}

      {:error, %ErrInput.Query{}} ->
        {:error, "invalid_filter"}

      {:error, _} ->
        {:error, "contract_calls_error"}
    end
  end

  def contract_calls(_, _args, _), do: {:error, "partial_state_unavailable"}

  # -------------- Helpers --------------
  defp build_logs_query(args) do
    acc = %{}
    acc = maybe_put(acc, "contract", Map.get(args, :contract_id))
    acc = maybe_put(acc, "data", Map.get(args, :data_prefix))
    acc = maybe_put(acc, "event", Map.get(args, :event))
    acc = maybe_put(acc, "function", Map.get(args, :function))
    acc = maybe_put(acc, "function_prefix", Map.get(args, :function_prefix))
    # boolean flags must be encoded with expected keys
    acc = maybe_put(acc, "aexn-args", encode_bool(Map.get(args, :aexn_args)))
    acc = maybe_put(acc, "custom-args", encode_bool(Map.get(args, :custom_args)))
    acc
  end

  defp build_calls_query(args) do
    acc = %{}
    acc = maybe_put(acc, "contract", Map.get(args, :contract_id))
    acc = maybe_put(acc, "function", Map.get(args, :function))
    acc = maybe_put(acc, "function_prefix", Map.get(args, :function_prefix))
    acc
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp encode_bool(nil), do: nil
  defp encode_bool(true), do: "true"
  defp encode_bool(false), do: "false"

  defp cursor_val(nil), do: nil
  defp cursor_val({val, _rev}), do: val

  defp clamp_limit(l) when is_integer(l) and l > @max_limit, do: @max_limit
  defp clamp_limit(l) when is_integer(l) and l > 0, do: l
  defp clamp_limit(_), do: 20
end
