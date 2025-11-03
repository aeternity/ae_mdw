defmodule AeMdwWeb.GraphQL.Resolvers.OracleResolver do
  @moduledoc """
  Oracle resolvers: single oracle lookup and paginated lists for oracles, queries, responses, and extends.
  """
  alias AeMdw.{Oracles}
  alias AeMdw.Db.State
  alias AeMdw.Error.Input, as: ErrInput

  @max_limit 100

  # -------------- Single Oracle --------------
  @spec oracle(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def oracle(_p, %{id: id}, %{context: %{state: %State{} = state}}) do
    case AeMdw.Validate.id(id, [:oracle_pubkey]) do
      {:ok, pk} ->
        case Oracles.fetch(state, pk, v3?: true) do
          {:ok, oracle} -> {:ok, oracle}
          {:error, %ErrInput.NotFound{}} -> {:error, "oracle_not_found"}
          {:error, _} -> {:error, "oracle_error"}
        end

      {:error, _} -> {:error, "invalid_oracle_id"}
    end
  end
  def oracle(_, _args, _), do: {:error, "partial_state_unavailable"}

  # -------------- Oracles list --------------
  @spec oracles(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def oracles(_p, args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    state_filter = args |> Map.get(:state)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)

    range =
      cond do
        from_h && to_h -> {:gen, from_h..to_h}
        to_h && is_nil(from_h) -> {:gen, 0..to_h}
        from_h && is_nil(to_h) -> {:gen, from_h..from_h}
        true -> nil
      end

    query =
      case state_filter do
        nil -> %{}
        v when is_atom(v) -> %{"state" => Atom.to_string(v)}
        v -> %{"state" => to_string(v)}
      end

    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Oracles.fetch_oracles(state, pagination, range, query, cursor, v3?: true) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}

      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, %ErrInput.Scope{}} -> {:error, "invalid_scope"}
      {:error, %ErrInput.Query{}} -> {:error, "invalid_filter"}
      {:error, _} -> {:error, "oracles_error"}
    end
  end
  def oracles(_, _args, _), do: {:error, "partial_state_unavailable"}

  # -------------- Oracle Queries --------------
  @spec oracle_queries(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def oracle_queries(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Oracles.fetch_oracle_queries(state, id, pagination, nil, cursor) do
      {:ok, {prev, queries, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: queries}}

      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, %ErrInput.NotFound{}} -> {:error, "oracle_not_found"}
      {:error, _} -> {:error, "oracle_queries_error"}
    end
  end
  def oracle_queries(_, _args, _), do: {:error, "partial_state_unavailable"}

  # -------------- Oracle Responses --------------
  @spec oracle_responses(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def oracle_responses(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
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

    case Oracles.fetch_oracle_responses(state, id, pagination, range, cursor) do
      {:ok, {prev, responses, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: responses}}

      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, %ErrInput.Scope{}} -> {:error, "invalid_scope"}
      {:error, %ErrInput.NotFound{}} -> {:error, "oracle_not_found"}
      {:error, _} -> {:error, "oracle_responses_error"}
    end
  end
  def oracle_responses(_, _args, _), do: {:error, "partial_state_unavailable"}

  # -------------- Oracle Extends --------------
  @spec oracle_extends(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def oracle_extends(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Oracles.fetch_oracle_extends(state, id, pagination, cursor) do
      {:ok, {prev, extends, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: extends}}

      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, %ErrInput.NotFound{}} -> {:error, "oracle_not_found"}
      {:error, _} -> {:error, "oracle_extends_error"}
    end
  end
  def oracle_extends(_, _args, _), do: {:error, "partial_state_unavailable"}

  # -------------- Helpers --------------
  defp cursor_val(nil), do: nil
  defp cursor_val({val, _rev}), do: val

  defp clamp_limit(l) when is_integer(l) and l > @max_limit, do: @max_limit
  defp clamp_limit(l) when is_integer(l) and l > 0, do: l
  defp clamp_limit(_), do: 20
end
