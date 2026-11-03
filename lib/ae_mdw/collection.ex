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
  @type pagination() :: direction_limit()
  @type pagination_cursor() :: {binary(), is_reversed?()} | nil
  @type stream_fn() :: (direction() -> Enumerable.t())

  @type range() :: {:gen, Range.t()} | {:txi, Range.t()} | {:epoch, Range.t()} | nil

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

    stream = State.stream(state, tab, direction, start_key(direction, first, cursor))

    if last do
      Stream.take_while(stream, fn key ->
        if direction == :forward, do: key <= last, else: key >= last
      end)
    else
      stream
    end
  end

  @doc """
  Same as stream/3 but using the State instead.
  """
  @spec stream(State.t(), table(), key()) :: Enumerable.t()
  def stream(state, table, boundary_start_key),
    do: State.stream(state, table, :forward, boundary_start_key)

  @doc """
  Merges any given stream of keys into a single stream, in sorted order and without dups.

  The streams that aren't read to the end are halted when the merged stream stops.
  """
  @spec merge([Enumerable.t()], direction()) :: Enumerable.t()
  def merge(streams, direction) do
    streams
    |> merge_sorted(direction)
    |> Stream.uniq()
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
  @spec gen_range(first :: term(), last :: term()) :: {:gen_range, term(), term()}
  def gen_range(first, last), do: {:gen_range, first, last}

  defp get_min_key(:pos_integer), do: 0
  defp get_min_key(:integer), do: Util.min_int()
  defp get_min_key(:integer_256bit), do: Util.min_256bit_int()
  defp get_min_key(:binary), do: Util.min_bin()
  defp get_min_key({:gen_range, first, _last}), do: first

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
  defp get_max_key({:gen_range, _first, last}), do: last

  defp get_max_key(x) when is_tuple(x) do
    x
    |> Tuple.to_list()
    |> Enum.map(&get_max_key/1)
    |> List.to_tuple()
  end

  defp get_max_key(x), do: x

  defp start_key(_direction, first, nil), do: first
  defp start_key(_direction, nil, cursor), do: cursor
  defp start_key(:forward, first, cursor), do: max(first, cursor)
  defp start_key(:backward, first, cursor), do: min(first, cursor)

  defp merge_sorted(streams, direction) do
    Stream.resource(
      fn -> Enum.reduce(streams, :gb_sets.new(), &add_next_key/2) end,
      &take_next_key(&1, direction),
      &halt_rest_streams/1
    )
  end

  defp add_next_key(stream, gb_set) do
    case StreamSplit.take_and_drop(stream, 1) do
      {[key], rest_stream} -> :gb_sets.add_element({key, rest_stream}, gb_set)
      {[], []} -> gb_set
    end
  end

  defp take_next_key(gb_set, direction) do
    if :gb_sets.is_empty(gb_set) do
      {:halt, gb_set}
    else
      {{key, rest_stream}, rest_set} =
        if direction == :forward do
          :gb_sets.take_smallest(gb_set)
        else
          :gb_sets.take_largest(gb_set)
        end

      {[key], add_next_key(rest_stream, rest_set)}
    end
  end

  defp halt_rest_streams(gb_set) do
    gb_set
    |> :gb_sets.to_list()
    |> Enum.each(fn {_key, rest_stream} ->
      Enumerable.reduce(rest_stream, {:halt, nil}, fn _key, nil -> {:cont, nil} end)
    end)
  end

  defp reverse_cursor(nil), do: nil
  defp reverse_cursor({cursor, is_reversed?}), do: {cursor, not is_reversed?}

  defp opposite_dir(:backward), do: :forward
  defp opposite_dir(:forward), do: :backward
end
