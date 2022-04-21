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

  @type stat() :: map()
  @type delta_stat() :: map()
  @type total_stat() :: map()
  @type cursor() :: binary() | nil

  @typep height() :: Blocks.height()
  @typep direction() :: Database.direction()
  @typep limit() :: Database.limit()
  @typep range() :: {:gen, Range.t()} | nil

  # Legacy v1 is a blending between /totalstats and /deltastats.
  # The active and inactive object counters are totals while the rewards are delta.
  @spec fetch_stats_v1(direction(), range(), cursor(), limit()) ::
          {cursor(), [stat()], cursor()}
  def fetch_stats_v1(direction, range, cursor, limit) do
    {:ok, last_gen} = Database.last_key(Model.TotalStat)

    range =
      case range do
        nil -> {1, last_gen}
        {:gen, %Range{first: first, last: last}} -> {max(first, 1), last}
      end

    cursor = deserialize_cursor(cursor)

    case Util.build_gen_pagination(cursor, direction, range, limit, last_gen) do
      {:ok, prev_cursor, range, next_cursor} ->
        {serialize_cursor(prev_cursor), render_stats(range), serialize_cursor(next_cursor)}

      :error ->
        {nil, [], nil}
    end
  end

  @spec fetch_delta_stats(direction(), range(), cursor(), limit()) ::
          {cursor(), [delta_stat()], cursor()}
  def fetch_delta_stats(direction, range, cursor, limit) do
    {:ok, last_gen} = Database.last_key(Model.DeltaStat)

    range =
      case range do
        nil -> {1, last_gen}
        {:gen, %Range{first: first, last: last}} -> {max(first, 1), last}
      end

    cursor = deserialize_cursor(cursor)

    case Util.build_gen_pagination(cursor, direction, range, limit, last_gen) do
      {:ok, prev_cursor, range, next_cursor} ->
        {serialize_cursor(prev_cursor), render_delta_stats(range), serialize_cursor(next_cursor)}

      :error ->
        {nil, [], nil}
    end
  end

  @spec fetch_total_stats(direction(), range(), cursor(), limit()) ::
          {cursor(), [total_stat()], cursor()}
  def fetch_total_stats(direction, range, cursor, limit) do
    {:ok, last_gen} = Database.last_key(Model.TotalStat)

    range =
      case range do
        nil -> {1, last_gen}
        {:gen, %Range{first: first, last: last}} -> {max(first, 1), last}
      end

    cursor = deserialize_cursor(cursor)

    case Util.build_gen_pagination(cursor, direction, range, limit, last_gen) do
      {:ok, prev_cursor, range, next_cursor} ->
        {serialize_cursor(prev_cursor), render_total_stats(range), serialize_cursor(next_cursor)}

      :error ->
        {nil, [], nil}
    end
  end

  @spec fetch_delta_stat!(height()) :: delta_stat()
  def fetch_delta_stat!(height), do: render_delta_stat(Database.fetch!(Model.DeltaStat, height))

  @spec fetch_total_stat!(height()) :: total_stat()
  def fetch_total_stat!(height), do: render_total_stat(Database.fetch!(Model.TotalStat, height))

  defp render_stats(%Range{first: first, last: last}) do
    Enum.map(first..last, fn height ->
      %{
        block_reward: block_reward,
        dev_reward: dev_reward
      } = fetch_delta_stat!(height - 1)

      %{
        active_auctions: active_auctions,
        active_names: active_names,
        inactive_names: inactive_names,
        active_oracles: active_oracles,
        inactive_oracles: inactive_oracles,
        contracts: contracts
      } = fetch_total_stat!(height)

      %{
        height: height,
        block_reward: block_reward,
        dev_reward: dev_reward,
        active_auctions: active_auctions,
        active_names: active_names,
        inactive_names: inactive_names,
        active_oracles: active_oracles,
        inactive_oracles: inactive_oracles,
        contracts: contracts
      }
    end)
  end

  defp render_delta_stats(gens), do: Enum.map(gens, &fetch_delta_stat!/1)

  defp render_total_stats(gens), do: Enum.map(gens, &fetch_total_stat!/1)

  defp render_delta_stat(stat), do: Format.to_map(stat, Model.DeltaStat)

  defp render_total_stat(total_stat), do: Format.to_map(total_stat, Model.TotalStat)

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
