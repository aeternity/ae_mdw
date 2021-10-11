defmodule AeMdw.Collection do
  @moduledoc """
  Basic module for dealing with paginated lists of items from Mnesia tables.
  """

  alias AeMdw.Mnesia

  @typep table() :: Mnesia.table()
  @typep direction() :: Mnesia.direction()
  @typep cursor() :: Mnesia.cursor()
  @typep limit() :: Mnesia.limit()
  @typep record() :: Mnesia.record()
  @typep key() :: Mnesia.key()

  @typep take_while_fn() :: term()
  @typep is_valid_key_fn() :: term()
  @typep sort_key_fn() :: term()
  @typep table_iterator() :: {table(), key(), take_while_fn(), is_valid_key_fn(), sort_key_fn()}

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
          :not_found -> acc
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
            :not_found -> {{next_key, table}, {Map.delete(next_keys, table), limit - 1}}
          end
      end)

    case Enum.split(keys, limit) do
      {keys, [{cursor, _cursor_table}]} -> {keys, cursor}
      {keys, []} -> {keys, nil}
    end
  end

  @doc """
  Merges the results from different tables (starting from a key for each table)
  into a single table in a sorted order.

  ## Examples

    iex> :mnesia.dirty_all_keys(:table1)
    [:a, :c, :g]
    iex> :mnesia.dirty_all_keys(:table2)
    [:b, :d, :e, :f]
    iex> true_fn = fn _key -> true end
    #Function<7.126501267/1 in :erl_eval.expr/5>
    iex> identity_fn = &(&1)
    #Function<7.126501267/1 in :erl_eval.expr/5>

    iex> table_iterators = [
    ...>   {:table1, :a, true_fn, true_fn, identity_fn}
    ...>   {:table2, :a, true_fn, true_fn, identity_fn}
    ...> ]
    iex> AeMdw.Collection.merge_with_keys(table_iterators, :forward, 3)
    {[{:a, :table1}, {:b, :table2}, {:c, :table1}], :d}


    iex> table_iterators = [
    ...>   {:table1, :a, &(&1 < :g), &(&1 != :c), identity_fn},
    ...>   {:table2, :a, &(&1 < :f), &(&1 != :d), identity_fn}
    ...> ]
    iex> AeMdw.Collection.merge_with_keys(table_iterators, :forward, 3)
    {[{:a, :table1}, {:b, :table2}, {:e, :table1}], nil}

  """
  @spec merge_with_keys([table_iterator()], direction(), limit()) ::
          {[{record(), table()}], cursor()}
  def merge_with_keys(table_iterators, direction, limit) do
    next_keys =
      Enum.reduce(table_iterators, %{}, fn {table, initial_key, take_while, is_valid_key?,
                                            sort_key},
                                           acc ->
        case next_key(table, direction, initial_key, take_while) do
          {:ok, next_key} ->
            Map.put(acc, {table, next_key}, {take_while, is_valid_key?, sort_key})

          :none ->
            acc
        end
      end)

    keys =
      Stream.unfold({next_keys, limit + 1}, fn
        {_next_keys, 0} ->
          nil

        {next_keys, _limit} when next_keys == %{} ->
          nil

        {next_keys, limit} ->
          {{table, next_key}, {take_while, is_valid_key?, sort_key}} =
            if direction == :backward do
              Enum.max_by(next_keys, fn {{_table, key}, {_take_while, _is_valid_key?, sort_key}} ->
                sort_key.(key)
              end)
            else
              Enum.min_by(next_keys, fn {{_table, key}, {_take_while, _is_valid_key?, sort_key}} ->
                sort_key.(key)
              end)
            end

          new_next_keys =
            case next_key(table, direction, next_key, take_while) do
              {:ok, new_key} ->
                Map.put(next_keys, {table, new_key}, {take_while, is_valid_key?, sort_key})

              :none ->
                Map.delete(next_keys, {table, next_key})
            end

          if is_valid_key?.(next_key) do
            {{next_key, table, sort_key.(next_key)}, {new_next_keys, limit - 1}}
          else
            {nil, {new_next_keys, limit}}
          end
      end)

    keys = Stream.reject(keys, &is_nil/1)

    case Enum.split(keys, limit) do
      {keys, [{_cursor, _cursor_table, cursor_sort_key}]} ->
        {Enum.map(keys, fn {key, tab, _sort_key} -> {key, tab} end), cursor_sort_key}

      {keys, []} ->
        {Enum.map(keys, fn {key, tab, _sort_key} -> {key, tab} end), nil}
    end
  end

  defp next_key(table, direction, key, take_while) do
    case Mnesia.next_key(table, direction, key) do
      {:ok, new_key} ->
        if take_while.(new_key) do
          {:ok, new_key}
        else
          :none
        end

      :not_found ->
        :none
    end
  end
end
