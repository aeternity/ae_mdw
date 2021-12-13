defmodule AeMdw.Stats do
  @moduledoc """
  Context module for dealing with Stats.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Mnesia

  require Model

  @type stat() :: map()
  @type sum_stat() :: map()
  @type cursor() :: binary() | nil

  @typep height() :: Blocks.height()
  @typep direction() :: Mnesia.direction()
  @typep limit() :: Mnesia.limit()
  @typep range() :: {:gen, Range.t()} | nil

  @table Model.Stat
  @sum_table Model.SumStat

  @spec fetch_stats(direction(), range(), cursor(), limit()) :: {[stat()], cursor()}
  def fetch_stats(direction, range, cursor, limit) do
    {:ok, {last_gen, -1}} = Mnesia.last_key(AeMdw.Db.Model.Block)

    range_scope = deserialize_scope(range)

    cursor_scope =
      case deserialize_cursor(cursor) do
        nil -> nil
        cursor when direction == :forward -> {cursor, cursor + limit + 1}
        cursor -> {cursor, cursor - limit - 1}
      end

    global_scope = if direction == :forward, do: {1, last_gen}, else: {last_gen, 1}

    case intersect_scopes([range_scope, cursor_scope, global_scope], direction) do
      {:ok, first, last} ->
        {gens, next_cursor} = Collection.paginate(first..last, limit)

        {render_stats(gens), serialize_cursor(next_cursor)}

      :error ->
        {[], nil}
    end
  end

  @spec fetch_sum_stats(direction(), range(), cursor(), limit()) :: {[sum_stat()], cursor()}
  def fetch_sum_stats(direction, range, cursor, limit) do
    {:ok, {last_gen, -1}} = Mnesia.last_key(AeMdw.Db.Model.Block)

    range_scope = deserialize_scope(range)

    cursor_scope =
      case deserialize_cursor(cursor) do
        nil -> nil
        cursor when direction == :forward -> {cursor, cursor + limit + 1}
        cursor -> {cursor, cursor - limit - 1}
      end

    global_scope = if direction == :forward, do: {0, last_gen}, else: {last_gen, 0}

    case intersect_scopes([range_scope, cursor_scope, global_scope], direction) do
      {:ok, first, last} ->
        {gens, next_cursor} = Collection.paginate(first..last, limit)

        {render_sum_stats(gens), serialize_cursor(next_cursor)}

      :error ->
        {[], nil}
    end
  end

  @spec fetch_stat!(height()) :: stat()
  def fetch_stat!(height), do: render_stat(Mnesia.fetch!(@table, height))

  @spec fetch_sum_stat!(height()) :: sum_stat()
  def fetch_sum_stat!(height), do: render_sum_stat(Mnesia.fetch!(@sum_table, height))

  defp intersect_scopes(scopes, direction) do
    scopes
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(fn
      {first, last}, {acc_first, acc_last} when direction == :forward ->
        {max(first, acc_first), min(last, acc_last)}

      {first, last}, {acc_first, acc_last} ->
        {min(first, acc_first), max(last, acc_last)}
    end)
    |> case do
      {first, last} when direction == :forward and first <= last -> {:ok, first, last}
      {_first, _last} when direction == :forward -> :error
      {first, last} when direction == :backward and first >= last -> {:ok, first, last}
      {_first, _last} when direction == :backward -> :error
    end
  end

  defp render_stats(gens), do: Enum.map(gens, &fetch_stat!/1)

  defp render_sum_stats(gens), do: Enum.map(gens, &fetch_sum_stat!/1)

  defp render_stat(stat), do: Format.to_map(stat, @table)

  defp render_sum_stat(sum_stat), do: Format.to_map(sum_stat, @sum_table)

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor(gen), do: Integer.to_string(gen)

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    case Integer.parse(cursor_bin) do
      {n, ""} when n >= 0 -> n
      {_n, _rest} -> nil
      :error -> nil
    end
  end

  defp deserialize_scope(nil), do: nil

  defp deserialize_scope({:gen, %Range{first: first_gen, last: last_gen}}),
    do: {first_gen, last_gen}
end
