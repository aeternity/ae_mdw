defmodule AeMdw.Stats do
  @moduledoc """
  Context module for dealing with Stats.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Mnesia
  alias AeMdw.Util

  require Model

  @type stat() :: map()
  @type sum_stat() :: map()
  @type cursor() :: binary() | nil

  @typep height() :: Blocks.height()
  @typep direction() :: Mnesia.direction()
  @typep limit() :: Mnesia.limit()
  @typep range() :: {:gen, Range.t()} | nil

  @table Model.Stat
  @sum_table Model.TotalStat

  @spec fetch_stats(direction(), range(), cursor(), limit()) :: {cursor(), [stat()], cursor()}
  def fetch_stats(direction, range, cursor, limit) do
    {:ok, last_gen} = Mnesia.last_key(AeMdw.Db.Model.Stat)

    {range_first, range_last} =
      case range do
        nil -> {1, last_gen}
        {:gen, %Range{first: first, last: last}} -> {max(first, 1), min(last, last_gen)}
      end

    cursor = deserialize_cursor(cursor)

    case Util.build_gen_pagination(cursor, direction, range_first, range_last, limit) do
      {:ok, prev_cursor, range, next_cursor} ->
        {serialize_cursor(prev_cursor), render_stats(range), serialize_cursor(next_cursor)}

      :error ->
        {nil, [], nil}
    end
  end

  @spec fetch_sum_stats(direction(), range(), cursor(), limit()) ::
          {cursor(), [sum_stat()], cursor()}
  def fetch_sum_stats(direction, range, cursor, limit) do
    {:ok, last_gen} = Mnesia.last_key(AeMdw.Db.Model.TotalStat)

    {range_first, range_last} =
      case range do
        nil -> {0, last_gen}
        {:gen, %Range{first: first, last: last}} -> {max(first, 0), min(last, last_gen)}
      end

    cursor = deserialize_cursor(cursor)

    case Util.build_gen_pagination(cursor, direction, range_first, range_last, limit) do
      {:ok, prev_cursor, range, next_cursor} ->
        {serialize_cursor(prev_cursor), render_sum_stats(range), serialize_cursor(next_cursor)}

      :error ->
        {nil, [], nil}
    end
  end

  @spec fetch_stat!(height()) :: stat()
  def fetch_stat!(height), do: render_stat(Mnesia.fetch!(@table, height))

  @spec fetch_sum_stat!(height()) :: sum_stat()
  def fetch_sum_stat!(height), do: render_sum_stat(Mnesia.fetch!(@sum_table, height))

  defp render_stats(gens), do: Enum.map(gens, &fetch_stat!/1)

  defp render_sum_stats(gens), do: Enum.map(gens, &fetch_sum_stat!/1)

  defp render_stat(stat), do: Format.to_map(stat, @table)

  defp render_sum_stat(sum_stat), do: Format.to_map(sum_stat, @sum_table)

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor(gen), do: {Integer.to_string(gen), false}

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    case Integer.parse(cursor_bin) do
      {n, ""} when n >= 0 -> n
      {_n, _rest} -> nil
      :error -> nil
    end
  end
end
