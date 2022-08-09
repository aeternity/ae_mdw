defmodule AeMdwWeb.StatsController do
  use AeMdwWeb, :controller

  alias AeMdw.Stats
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec stats_v1(Conn.t(), map()) :: Conn.t()
  def stats_v1(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: {direction, _is_reversed?, limit, _has_cursor?},
      cursor: cursor,
      scope: scope
    } = assigns

    {prev_cursor, stats, next_cursor} =
      Stats.fetch_stats_v1(state, direction, scope, cursor, limit)

    Util.paginate(conn, prev_cursor, stats, next_cursor)
  end

  @spec delta_stats(Conn.t(), map()) :: Conn.t()
  def delta_stats(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: {direction, _is_reversed?, limit, _has_cursor?},
      cursor: cursor,
      scope: scope
    } = assigns

    {prev_cursor, stats, next_cursor} =
      Stats.fetch_delta_stats(state, direction, scope, cursor, limit)

    Util.paginate(conn, prev_cursor, stats, next_cursor)
  end

  @spec total_stats(Conn.t(), map()) :: Conn.t()
  def total_stats(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: {direction, _is_reversed?, limit, _has_cursor?},
      cursor: cursor,
      scope: scope
    } = assigns

    {prev_cursor, stats, next_cursor} =
      Stats.fetch_total_stats(state, direction, scope, cursor, limit)

    Util.paginate(conn, prev_cursor, stats, next_cursor)
  end

  @spec stats(Conn.t(), map()) :: Conn.t()
  def stats(%Conn{assigns: %{state: state}} = conn, _params) do
    case Stats.fetch_stats(state) do
      {:ok, stats} -> json(conn, stats)
      {:error, reason} -> {:error, reason}
    end
  end
end
