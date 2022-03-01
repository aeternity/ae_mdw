defmodule AeMdwWeb.StatsController do
  use AeMdwWeb, :controller

  alias AeMdw.Stats
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)

  @spec stats(Conn.t(), map()) :: Conn.t()
  def stats(%Conn{assigns: assigns} = conn, _params) do
    %{pagination: {direction, _is_reversed?, limit, _has_cursor?}, cursor: cursor, scope: scope} =
      assigns

    {prev_cursor, stats, next_cursor} = Stats.fetch_delta_stats(direction, scope, cursor, limit)

    Util.paginate(conn, prev_cursor, stats, next_cursor)
  end

  @spec delta_stats(Conn.t(), map()) :: Conn.t()
  def delta_stats(%Conn{assigns: assigns} = conn, _params) do
    %{pagination: {direction, _is_reversed?, limit, _has_cursor?}, cursor: cursor, scope: scope} =
      assigns

    {prev_cursor, stats, next_cursor} = Stats.fetch_delta_stats(direction, scope, cursor, limit)

    Util.paginate(conn, prev_cursor, stats, next_cursor)
  end

  @spec total_stats(Conn.t(), map()) :: Conn.t()
  def total_stats(%Conn{assigns: assigns} = conn, _params) do
    %{pagination: {direction, _is_reversed?, limit, _has_cursor?}, cursor: cursor, scope: scope} =
      assigns

    {prev_cursor, stats, next_cursor} = Stats.fetch_total_stats(direction, scope, cursor, limit)

    Util.paginate(conn, prev_cursor, stats, next_cursor)
  end
end
