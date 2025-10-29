defmodule AeMdwWeb.GraphQL.Resolvers.StatsResolver do
  alias AeMdw.Miners
  alias AeMdw.Stats

  def total(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 10))
    cursor = Map.get(args, :cursor)
    {prev, data, next} = Stats.fetch_total_stats(state, :backward, nil, cursor, limit)

    {:ok,
     %{
       prev_cursor: cursor_val(prev),
       next_cursor: cursor_val(next),
       data: data
     }}
  end

  def delta(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 10))
    cursor = Map.get(args, :cursor)
    {prev, data, next} = Stats.fetch_delta_stats(state, :backward, nil, cursor, limit)

    {:ok,
     %{
       prev_cursor: cursor_val(prev),
       next_cursor: cursor_val(next),
       data: data
     }}
  end

  def miners(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 10))
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}
    {:ok, {prev, data, next}} = Miners.fetch_miners(state, pagination, cursor)

    {:ok,
     %{
       prev_cursor: cursor_val(prev),
       next_cursor: cursor_val(next),
       data: data
     }}
  end

  def transactions(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 10))
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    {:ok, {prev, data, next}} =
      Stats.fetch_transactions_stats(state, pagination, [], nil, cursor)

    {:ok,
     %{
       prev_cursor: cursor_val(prev),
       next_cursor: cursor_val(next),
       data: data
     }}
  end

  def blocks(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 10))
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    {:ok, {prev, data, next}} =
      Stats.fetch_blocks_stats(state, pagination, [], nil, cursor)

    {:ok,
     %{
       prev_cursor: cursor_val(prev),
       next_cursor: cursor_val(next),
       data: data
     }}
  end

  def names(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 10))
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    {:ok, {prev, data, next}} =
      Stats.fetch_names_stats(state, pagination, [], nil, cursor)

    {:ok,
     %{
       prev_cursor: cursor_val(prev),
       next_cursor: cursor_val(next),
       data: data
     }}
  end

  def stats(_p, _args, %{context: %{state: state}}) when not is_nil(state) do
    Stats.fetch_stats(state)
  end

  defp cursor_val(nil), do: nil
  defp cursor_val({val, _rev}), do: val

  defp clamp_limit(l) when is_integer(l) and l > 100, do: 100
  defp clamp_limit(l) when is_integer(l) and l > 0, do: l
  defp clamp_limit(_), do: 10
end
