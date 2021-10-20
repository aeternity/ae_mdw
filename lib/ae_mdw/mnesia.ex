defmodule AeMdw.Mnesia do
  @moduledoc """
  Mnesia wrapper to provide a simpler API.

  In order to iterate throught collections of records we use the
  concept of "cursor". A cursor is just a key of any given table that
  is returned in order the access the next page of records.

  This cursor key is whatever the current key of the table might be
  (e.g. a tuple, a number). If there is no next page, `nil` is
  returned instead.
  """

  @type table() :: atom()
  @type record() :: tuple()
  @type key() :: term()
  @type direction() :: :forward | :backward
  @type cursor() :: key() | nil
  @type limit() :: pos_integer()

  @end_token :"$end_of_table"

  @spec last_key(table(), term()) :: term()
  def last_key(tab, default) do
    case last_key(tab) do
      {:ok, last_key} -> last_key
      :none -> default
    end
  end

  @spec last_key(table()) :: {:ok, key()} | :none
  def last_key(tab) do
    case :mnesia.dirty_last(tab) do
      @end_token -> :none
      last_key -> {:ok, last_key}
    end
  end

  @spec first_key(table(), term()) :: term()
  def first_key(tab, default) do
    case first_key(tab) do
      {:ok, first_key} -> first_key
      :none -> default
    end
  end

  @spec first_key(table()) :: {:ok, key()} | :none
  def first_key(tab) do
    case :mnesia.dirty_first(tab) do
      @end_token -> :none
      last_key -> {:ok, last_key}
    end
  end

  @spec prev_key(table(), key()) :: {:ok, key()} | :none
  def prev_key(tab, key) do
    case :mnesia.dirty_prev(tab, key) do
      @end_token -> :none
      record -> {:ok, record}
    end
  end

  @spec fetch(table(), key()) :: {:ok, record()} | :not_found
  def fetch(tab, key) do
    case :mnesia.dirty_read(tab, key) do
      [record] -> {:ok, record}
      [] -> :not_found
    end
  end

  @spec fetch!(table(), key()) :: record()
  def fetch!(tab, key) do
    {:ok, record} = fetch(tab, key)

    record
  end

  @spec exists?(table(), key()) :: boolean()
  def exists?(tab, key) do
    match?({:ok, _record}, fetch(tab, key))
  end

  @spec next_key(table(), direction(), cursor()) :: {:ok, key()} | :not_found
  def next_key(tab, :forward, nil), do: first_key(tab)

  def next_key(tab, :forward, cursor) do
    case :mnesia.dirty_next(tab, cursor) do
      @end_token -> :not_found
      record -> {:ok, record}
    end
  end

  def next_key(tab, :backward, nil), do: last_key(tab)

  def next_key(tab, :backward, cursor) do
    case :mnesia.dirty_prev(tab, cursor) do
      @end_token -> :not_found
      record -> {:ok, record}
    end
  end

  @spec fetch_keys(table(), direction(), cursor(), limit()) :: {[record()], cursor()}
  def fetch_keys(tab, :forward, nil, limit) do
    {keys, cursor} =
      :mnesia.async_dirty(fn ->
        case :mnesia.first(tab) do
          @end_token -> {[], nil}
          first_key -> fetch_forward_keys(tab, first_key, limit)
        end
      end)

    {keys, cursor}
  end

  def fetch_keys(tab, :forward, first_key, limit) do
    {keys, cursor} =
      :mnesia.async_dirty(fn ->
        case :mnesia.read(tab, first_key) do
          [] -> {[], nil}
          _first_record -> fetch_forward_keys(tab, first_key, limit)
        end
      end)

    {keys, cursor}
  end

  def fetch_keys(tab, :backward, nil, limit) do
    {keys, cursor} =
      :mnesia.async_dirty(fn ->
        case :mnesia.last(tab) do
          @end_token -> {[], nil}
          last_key -> fetch_backward_keys(tab, last_key, limit)
        end
      end)

    {keys, cursor}
  end

  def fetch_keys(tab, :backward, last_key, limit) do
    {keys, cursor} =
      :mnesia.async_dirty(fn ->
        case :mnesia.read(tab, last_key) do
          [] -> {[], nil}
          _last_record -> fetch_backward_keys(tab, last_key, limit)
        end
      end)

    {keys, cursor}
  end

  defp fetch_forward_keys(tab, first_key, limit) do
    keys =
      Stream.unfold({limit, first_key}, fn
        {0, _current_key} ->
          nil

        {n, current_key} ->
          case :mnesia.next(tab, current_key) do
            @end_token -> nil
            next_key -> {next_key, {n - 1, next_key}}
          end
      end)

    case Enum.split(keys, limit - 1) do
      {keys, [next_key]} -> {[first_key | keys], next_key}
      {keys, []} -> {[first_key | keys], nil}
    end
  end

  defp fetch_backward_keys(tab, last_key, limit) do
    keys =
      Stream.unfold({limit, last_key}, fn
        {0, _current_key} ->
          nil

        {n, current_key} ->
          case :mnesia.prev(tab, current_key) do
            @end_token -> nil
            prev_key -> {prev_key, {n - 1, prev_key}}
          end
      end)

    case Enum.split(keys, limit - 1) do
      {keys, [prev_key]} -> {[last_key | keys], prev_key}
      {keys, []} -> {[last_key | keys], nil}
    end
  end
end
