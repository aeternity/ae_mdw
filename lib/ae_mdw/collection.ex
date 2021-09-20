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

  @doc """
  Returns the cursor-paginated results of 2 different mnesia tables, where the
  results of one come after the other, depending on the direction.

  ## Examples

    iex> :mnesia.dirty_all_keys(:table1)
    [:a, :b]
    iex> :mnesia.dirty_all_keys(:table2)
    [:c, :d, :e]
    iex> AeMdw.Collection.concat(:table1, :table2, :forward, nil, 3)
    {[{:a, :table1}, {:b, :table1}, {:c, :table1}], :d}
    iex> AeMdw.Collection.concat(:table1, :table2, :backward, nil, 4)
    {[{:e, :table2}, {:d, :table2}, {:c, :table2}, {:b, :table1}], :a}
    iex> AeMdw.Collection.concat(:table1, :table2, :forward, :d, 4)
    {[{:d, :table2}, {:e, :table2}], nil}

  """
  @spec concat(table(), table(), direction(), cursor(), limit()) ::
          {[{record(), table()}], cursor()}
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

    {Enum.map(start_keys, &{&1, start_table}) ++ Enum.map(end_keys, &{&1, end_table}), next_key}
  end
end
