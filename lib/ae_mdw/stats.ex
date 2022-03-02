defmodule AeMdw.Stats do
  @moduledoc """
  Context module for dealing with Stats.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Util

  require Model

  @type delta_stat() :: map()
  @type total_stat() :: map()
  @type cursor() :: binary() | nil

  @typep height() :: Blocks.height()
  @typep direction() :: Database.direction()
  @typep limit() :: Database.limit()
  @typep range() :: {:gen, Range.t()} | nil

  @delta_table Model.DeltaStat
  @totals_table Model.TotalStat

  @spec fetch_delta_stats(direction(), range(), cursor(), limit()) ::
          {cursor(), [delta_stat()], cursor()}
  def fetch_delta_stats(direction, range, cursor, limit) do
    {:ok, last_gen} = Database.last_key(AeMdw.Db.Model.DeltaStat)

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

  @spec fetch_total_stats(direction(), range(), cursor(), limit()) ::
          {cursor(), [total_stat()], cursor()}
  def fetch_total_stats(direction, range, cursor, limit) do
    {:ok, last_gen} = Database.last_key(AeMdw.Db.Model.TotalStat)

    {range_first, range_last} =
      case range do
        nil -> {0, last_gen}
        {:gen, %Range{first: first, last: last}} -> {max(first, 0), min(last, last_gen)}
      end

    cursor = deserialize_cursor(cursor)

    case Util.build_gen_pagination(cursor, direction, range_first, range_last, limit) do
      {:ok, prev_cursor, range, next_cursor} ->
        {serialize_cursor(prev_cursor), render_total_stats(range), serialize_cursor(next_cursor)}

      :error ->
        {nil, [], nil}
    end
  end

  @spec fetch_stat!(height()) :: delta_stat()
  def fetch_stat!(height), do: render_stat(Database.fetch!(@delta_table, height))

  @spec fetch_total_stat!(height()) :: total_stat()
  def fetch_total_stat!(height), do: render_total_stat(Database.fetch!(@totals_table, height))

  defp render_stats(gens), do: Enum.map(gens, &fetch_stat!/1)

  defp render_total_stats(gens), do: Enum.map(gens, &fetch_total_stat!/1)

  defp render_stat(stat), do: Format.to_map(stat, @delta_table)

  defp render_total_stat(total_stat), do: Format.to_map(total_stat, @totals_table)

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
