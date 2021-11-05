defmodule AeMdw.Collection do
  @moduledoc """
  Basic module for dealing with paginated lists of items from Mnesia tables.
  """

  alias AeMdw.Mnesia

  @typep table() :: Mnesia.table()
  @typep direction() :: Mnesia.direction()
  @typep cursor() :: Mnesia.cursor()
  @typep limit() :: Mnesia.limit()
  @typep key() :: Mnesia.key()
  @typep record() :: Mnesia.record()
  @typep scope() :: {key(), key()} | nil

  @doc """
  Paginates a list or stream or records into a list of items and it's next cursor (if
  any).
  """
  @spec paginate(Enumerable.t(), limit()) :: {[record()], cursor()}
  def paginate(enumerable, limit) do
    enumerable
    |> Stream.take(limit + 1)
    |> Enum.split(limit)
    |> case do
      {records, []} -> {records, nil}
      {records, [cursor]} -> {records, cursor}
    end
  end

  @doc """
  Builds a stream from records from a table starting from the initial_key given.
  """
  @spec stream(table(), direction(), scope(), cursor()) :: Enumerable.t()
  def stream(tab, direction, scope, cursor) do
    {first, last} = scope || {nil, nil}

    case fetch_first_key(tab, direction, first, cursor) do
      {:ok, first_key} -> unfold_stream(tab, direction, first_key, last)
      :none -> []
    end
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
          case Mnesia.next_key(tab, direction, key) do
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

  defp fetch_first_key(tab, direction, nil, nil), do: Mnesia.next_key(tab, direction, nil)

  defp fetch_first_key(tab, direction, first, nil), do: fetch_first_key(tab, direction, first)

  defp fetch_first_key(tab, direction, nil, cursor), do: fetch_first_key(tab, direction, cursor)

  defp fetch_first_key(tab, :forward, first, cursor),
    do: fetch_first_key(tab, :forward, max(first, cursor))

  defp fetch_first_key(tab, :backward, first, cursor),
    do: fetch_first_key(tab, :backward, min(first, cursor))

  defp fetch_first_key(tab, direction, candidate_cursor) do
    if Mnesia.exists?(tab, candidate_cursor) do
      {:ok, candidate_cursor}
    else
      Mnesia.next_key(tab, direction, candidate_cursor)
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
end
