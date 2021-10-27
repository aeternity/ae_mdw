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

  @doc """
  Returns the cursor-paginated results of 2 different mnesia tables, where the
  results of one come after the other, depending on the direction.

  ## Examples

    iex> :mnesia.dirty_all_keys(:table1)
    [:a, :b]
    iex> :mnesia.dirty_all_keys(:table2)
    [:c, :d, :e]
    iex> AeMdw.Collection.concat(:table1, :table2, :forward, nil, 3)
    {{:table1, [:a, :b]}, {:table2, [:c]}, :d}
    iex> AeMdw.Collection.concat(:table1, :table2, :backward, nil, 4)
    {{:table2, [:e, :d, :c, :b]}, {:table1, []}, :a}
    iex> AeMdw.Collection.concat(:table1, :table2, :forward, :d, 4)
    {{:table2, [:d, :e]}, {:table1, []}, nil}

  """
  @spec concat(table(), table(), direction(), cursor(), limit()) ::
          {{table(), [record()]}, {table(), [record()]}, cursor()}
  def concat(first_table, last_table, direction, cursor, limit) do
    {start_table, end_table} =
      case direction do
        :forward -> {first_table, last_table}
        :backward -> {last_table, first_table}
      end

    {start_keys, end_keys, next_key} =
      case Mnesia.fetch_keys(start_table, direction, cursor, limit) do
        {[], nil} ->
          {end_keys, next_cursor} = Mnesia.fetch_keys(end_table, direction, cursor, limit)

          {[], end_keys, next_cursor}

        {start_keys, nil} when length(start_keys) == limit ->
          next_key =
            case direction do
              :backward -> Mnesia.last_key(end_table, nil)
              :forward -> Mnesia.first_key(end_table, nil)
            end

          {start_keys, [], next_key}

        {start_keys, nil} ->
          {end_keys, next_cursor} =
            Mnesia.fetch_keys(end_table, direction, nil, limit - length(start_keys))

          {start_keys, end_keys, next_cursor}

        {start_keys, end_cursor} ->
          {start_keys, [], end_cursor}
      end

    {{start_table, start_keys}, {end_table, end_keys}, next_key}
  end

  @doc """
  Merges the results from different tables into a single table in a sorted order.

  ## Examples

    iex> :mnesia.dirty_all_keys(:table1)
    [:a, :c]
    iex> :mnesia.dirty_all_keys(:table2)
    [:b, :d, :e]
    iex> AeMdw.Collection.merge([:table1, :table2], :forward, nil, 3)
    {[{:a, :table1}, {:b, :table2}, {:c, :table1}], :d}
    iex> AeMdw.Collection.merge([:table1, :table2], :forward, :d, 3)
    {[{:d, :table2}, {:e, :table2}], nil}

  """
  @spec merge([table()], direction(), cursor(), limit()) :: {[{record(), table()}], cursor()}
  def merge(tables, direction, cursor, limit) do
    next_keys =
      Enum.reduce(tables, %{}, fn table, acc ->
        case Mnesia.next_key(table, direction, cursor) do
          {:ok, next_key} -> Map.put(acc, table, next_key)
          :none -> acc
        end
      end)

    keys =
      Stream.unfold({next_keys, limit + 1}, fn
        {_next_keys, 0} ->
          nil

        {next_keys, _limit} when next_keys == %{} ->
          nil

        {next_keys, limit} ->
          {table, next_key} =
            if direction == :backward do
              Enum.max_by(next_keys, fn {_table, key} -> key end)
            else
              Enum.min_by(next_keys, fn {_table, key} -> key end)
            end

          case Mnesia.next_key(table, direction, next_key) do
            {:ok, new_key} -> {{next_key, table}, {Map.put(next_keys, table, new_key), limit - 1}}
            :none -> {{next_key, table}, {Map.delete(next_keys, table), limit - 1}}
          end
      end)

    case Enum.split(keys, limit) do
      {keys, [{cursor, _cursor_table}]} -> {keys, cursor}
      {keys, []} -> {keys, nil}
    end
  end

  @doc """
  Builds a stream from records from a table starting from the initial_key given.
  """
  @spec stream(table(), direction(), cursor()) :: Enumerable.t()
  def stream(tab, direction, cursor) do
    case fetch_first_key(tab, direction, cursor) do
      {:ok, first_key} -> unfold_stream(tab, direction, first_key)
      :none -> []
    end
  end

  @doc """
  Merges any given stream of keys into a single stream, in sorted order and without dups.
  """
  @spec merge_streams([Enumerable.t()], direction(), limit()) :: {[key()], cursor()}
  def merge_streams(streams, direction, limit) do
    streams
    |> Enum.reduce(:gb_sets.new(), fn stream, acc ->
      case StreamSplit.take_and_drop(stream, 1) do
        {[first_key], rest} -> :gb_sets.add_element({first_key, rest}, acc)
        {[], []} -> acc
      end
    end)
    |> merge_streams_by(direction)
    |> remove_dups()
    |> Stream.take(limit + 1)
    |> Enum.split(limit)
    |> case do
      {keys, [cursor]} -> {keys, cursor}
      {keys, []} -> {keys, nil}
    end
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

  defp unfold_stream(tab, direction, first_key) do
    Stream.unfold(first_key, fn
      :end_keys ->
        nil

      key ->
        case Mnesia.next_key(tab, direction, key) do
          {:ok, next_key} -> {key, next_key}
          :none -> {key, :end_keys}
        end
    end)
  end

  defp fetch_first_key(tab, direction, nil), do: Mnesia.next_key(tab, direction, nil)

  defp fetch_first_key(tab, direction, cursor) do
    if Mnesia.exists?(tab, cursor) do
      {:ok, cursor}
    else
      Mnesia.next_key(tab, direction, cursor)
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
