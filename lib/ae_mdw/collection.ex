defmodule AeMdw.Collection do
  @moduledoc """
  Basic module for dealing with paginated lists of items from Database tables.
  """

  alias AeMdw.Database
  alias AeMdw.Util

  @typep table() :: Database.table()
  @typep direction() :: Database.direction()
  @typep cursor() :: Database.cursor()
  @typep limit() :: Database.limit()
  @typep key() :: Database.key()
  @typep key_boundary() :: {key(), key()} | nil

  @type is_reversed?() :: boolean()
  @type has_cursor?() :: boolean()
  @type direction_limit() :: {direction(), is_reversed?(), limit(), has_cursor?()}
  @type pagination_cursor() :: {cursor(), is_reversed?()} | nil
  @type stream_fn() :: (direction() -> Enumerable.t())

  @doc """
  Paginates a list or stream or records into a list of items and it's next cursor (if
  any).
  """
  @spec paginate(stream_fn(), direction_limit()) ::
          {pagination_cursor(), Enumerable.t(), pagination_cursor()}
  def paginate(stream_fn, {direction, false, limit, has_cursor?}) do
    prev_cursor =
      if has_cursor? do
        case Enum.at(stream_fn.(Util.opposite_dir(direction)), 1) do
          nil -> nil
          cursor -> {cursor, true}
        end
      end

    direction
    |> stream_fn.()
    |> Stream.take(limit + 1)
    |> Enum.split(limit)
    |> case do
      {records, []} -> {prev_cursor, records, nil}
      {records, [next_cursor]} -> {prev_cursor, records, {next_cursor, false}}
    end
  end

  def paginate(stream_fn, {direction, true, limit, has_cursor?}) do
    {prev_cursor, records, next_cursor} =
      paginate(stream_fn, {Util.opposite_dir(direction), false, limit, has_cursor?})

    {reverse_cursor(next_cursor), Enum.reverse(records), reverse_cursor(prev_cursor)}
  end

  @doc """
  Builds a stream from records from a table starting from the initial_key given.
  """
  @spec stream(table(), direction(), key_boundary(), cursor()) :: Enumerable.t()
  def stream(tab, direction, key_boundary, cursor) do
    {first, last} =
      case {key_boundary, direction} do
        {nil, _dir} -> {nil, nil}
        {s, :forward} -> s
        {{last, first}, :backward} -> {first, last}
      end

    case fetch_first_key(tab, direction, first, cursor) do
      {:ok, first_key} -> unfold_stream(tab, direction, first_key, last)
      :none -> []
    end
  end

  @doc """
  Streams forward a table seeking the iterator to a boundary start key.
  """
  @spec stream(table(), key()) :: Enumerable.t()
  def stream(table, boundary_start_key) do
    Stream.unfold(
      boundary_start_key,
      fn key ->
        case Database.next_key(table, key) do
          {:ok, next_key} -> {next_key, next_key}
          :none -> nil
        end
      end
    )
  end

  @doc """
  Merges any given stream of keys into a single stream, in sorted order and without dups.
  """
  @spec merge([Enumerable.t()], direction()) :: Enumerable.t()
  def merge(streams, direction) do
    streams
    |> Enum.reduce(:gb_sets.new(), fn stream, acc ->
      case StreamSplit.take_and_drop(stream, 1) do
        {[first_key], rest} -> :gb_sets.add_element({first_key, rest}, acc)
        {[], []} -> acc
      end
    end)
    |> merge_streams_by(direction)
    |> remove_dups()
  end

  defp remove_dups(stream) do
    Stream.transform(stream, [], fn
      item, visited_keys ->
        if item in visited_keys do
          {[], [item | visited_keys]}
        else
          {[item], [item | visited_keys]}
        end
    end)
  end

  defp unfold_stream(tab, direction, first_key, last_key) do
    stream =
      Stream.unfold(first_key, fn
        :end_keys ->
          nil

        key ->
          case Database.next_key(tab, direction, key) do
            {:ok, next_key} -> {key, next_key}
            :none -> {key, :end_keys}
          end
      end)

    if last_key do
      Stream.take_while(stream, fn key ->
        if direction == :forward, do: key <= last_key, else: key >= last_key
      end)
    else
      stream
    end
  end

  defp fetch_first_key(tab, direction, nil, nil), do: Database.next_key(tab, direction, nil)

  defp fetch_first_key(tab, direction, first, nil), do: fetch_first_key(tab, direction, first)

  defp fetch_first_key(tab, direction, nil, cursor), do: fetch_first_key(tab, direction, cursor)

  defp fetch_first_key(tab, :forward, first, cursor),
    do: fetch_first_key(tab, :forward, max(first, cursor))

  defp fetch_first_key(tab, :backward, first, cursor),
    do: fetch_first_key(tab, :backward, min(first, cursor))

  defp fetch_first_key(tab, direction, candidate_cursor) do
    if Database.exists?(tab, candidate_cursor) do
      {:ok, candidate_cursor}
    else
      Database.next_key(tab, direction, candidate_cursor)
    end
  end

  defp merge_streams_by(gb_set, direction) do
    Stream.unfold(gb_set, fn gb_set ->
      if :gb_sets.is_empty(gb_set) do
        nil
      else
        {{key, rest_stream}, rest_set} =
          if direction == :forward do
            :gb_sets.take_smallest(gb_set)
          else
            :gb_sets.take_largest(gb_set)
          end

        case StreamSplit.take_and_drop(rest_stream, 1) do
          {[next_key], next_stream} ->
            {key, :gb_sets.add_element({next_key, next_stream}, rest_set)}

          {[], []} ->
            {key, rest_set}
        end
      end
    end)
  end

  defp reverse_cursor(nil), do: nil
  defp reverse_cursor({cursor, is_reversed?}), do: {cursor, not is_reversed?}
end
