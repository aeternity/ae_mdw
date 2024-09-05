defmodule AeMdw.Collection do
  @moduledoc """
  Basic module for dealing with paginated lists of items from Database tables.
  """

  alias AeMdw.Database
  alias AeMdw.Db.State
  alias AeMdw.Util

  @typep table() :: Database.table()
  @typep key() :: Database.key()
  @typep record() :: Database.record()

  @type cursor() :: Database.cursor()
  @type direction() :: Database.direction()
  @type limit() :: Database.limit()
  @type key_boundary() :: {key(), key()} | nil

  @type is_reversed?() :: boolean()
  @type has_cursor?() :: boolean()
  @type direction_limit() :: {direction(), is_reversed?(), limit(), has_cursor?()}
  @type pagination_cursor() :: {binary(), is_reversed?()} | nil
  @type stream_fn() :: (direction() -> Enumerable.t())

  @doc """
  Paginates a list or stream or records into a list of items and it's next cursor (if
  any).
  """
  @spec paginate(stream_fn(), direction_limit(), (record() -> term()), (key() -> binary())) ::
          {pagination_cursor(), Enumerable.t(), pagination_cursor()}
  def paginate(
        stream_fn,
        {direction, false, limit, has_cursor?},
        render_record_fn,
        serialize_cursor_fn
      ) do
    prev_cursor =
      if has_cursor? do
        case Enum.at(stream_fn.(opposite_dir(direction)), 1) do
          nil -> nil
          cursor -> {serialize_cursor_fn.(cursor), true}
        end
      end

    direction
    |> stream_fn.()
    |> Stream.take(limit + 1)
    |> Enum.split(limit)
    |> case do
      {records, []} ->
        {prev_cursor, Enum.map(records, render_record_fn), nil}

      {records, [next_cursor]} ->
        {prev_cursor, Enum.map(records, render_record_fn),
         {serialize_cursor_fn.(next_cursor), false}}
    end
  end

  def paginate(
        stream_fn,
        {direction, true, limit, has_cursor?},
        serialize_record_fn,
        serialize_cursor_fn
      ) do
    {prev_cursor, records, next_cursor} =
      paginate(
        stream_fn,
        {opposite_dir(direction), false, limit, has_cursor?},
        serialize_record_fn,
        serialize_cursor_fn
      )

    {reverse_cursor(next_cursor), Enum.reverse(records), reverse_cursor(prev_cursor)}
  end

  @doc """
  Builds a stream from records from a table starting from the initial_key given using
  a State.
  """
  @spec stream(State.t(), table(), direction(), key_boundary(), cursor()) :: Enumerable.t()
  def stream(state, tab, direction, key_boundary, cursor) do
    {first, last} =
      case {key_boundary, direction} do
        {nil, _dir} -> {nil, nil}
        {s, :forward} -> s
        {{last, first}, :backward} -> {first, last}
      end

    case fetch_first_key(state, tab, direction, first, cursor) do
      {:ok, first_key} -> unfold_stream(state, tab, direction, first_key, last)
      :none -> []
    end
  end

  @doc """
  Same as stream/3 but using the State instead.
  """
  @spec stream(State.t(), table(), key()) :: Enumerable.t()
  def stream(state, table, boundary_start_key) do
    case fetch_first_key(state, table, :forward, boundary_start_key, nil) do
      {:ok, first_key} -> unfold_stream(state, table, :forward, first_key, nil)
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

  @spec generate_key_boundary(tuple()) :: key_boundary()
  def generate_key_boundary(key) do
    key
    |> Tuple.to_list()
    |> Enum.map(&{get_min_key(&1), get_max_key(&1)})
    |> Enum.unzip()
    |> then(fn {first, last} -> {List.to_tuple(first), List.to_tuple(last)} end)
  end

  @spec pos_integer() :: :pos_integer
  def pos_integer(), do: :pos_integer
  @spec integer() :: :integer
  def integer(), do: :integer
  @spec integer_256bit() :: :integer_256bit
  def integer_256bit(), do: :integer_256bit
  @spec binary() :: :binary
  def binary(), do: :binary

  defp get_min_key(:pos_integer), do: 0
  defp get_min_key(:integer), do: Util.min_int()
  defp get_min_key(:integer_256bit), do: Util.min_256bit_int()
  defp get_min_key(:binary), do: Util.min_bin()

  defp get_min_key(x) when is_tuple(x) do
    x
    |> Tuple.to_list()
    |> Enum.map(&get_min_key/1)
    |> List.to_tuple()
  end

  defp get_min_key(x), do: x

  defp get_max_key(:pos_integer), do: Util.max_int()
  defp get_max_key(:integer), do: Util.max_int()
  defp get_max_key(:integer_256bit), do: Util.max_int()
  defp get_max_key(:binary), do: Util.max_256bit_bin()

  defp get_max_key(x) when is_tuple(x) do
    x
    |> Tuple.to_list()
    |> Enum.map(&get_max_key/1)
    |> List.to_tuple()
  end

  defp get_max_key(x), do: x

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

  defp unfold_stream(state, tab, direction, first_key, last_key) do
    stream =
      Stream.unfold(first_key, fn
        :end_keys ->
          nil

        key ->
          case State.next(state, tab, direction, key) do
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

  defp fetch_first_key(state, tab, direction, nil, nil),
    do: State.next(state, tab, direction, nil)

  defp fetch_first_key(state, tab, direction, first, nil),
    do: fetch_first_key(state, tab, direction, first)

  defp fetch_first_key(state, tab, direction, nil, cursor),
    do: fetch_first_key(state, tab, direction, cursor)

  defp fetch_first_key(state, tab, :forward, first, cursor),
    do: fetch_first_key(state, tab, :forward, max(first, cursor))

  defp fetch_first_key(state, tab, :backward, first, cursor),
    do: fetch_first_key(state, tab, :backward, min(first, cursor))

  defp fetch_first_key(state, tab, direction, candidate_cursor) do
    if State.exists?(state, tab, candidate_cursor) do
      {:ok, candidate_cursor}
    else
      State.next(state, tab, direction, candidate_cursor)
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

  defp opposite_dir(:backward), do: :forward
  defp opposite_dir(:forward), do: :backward
end
