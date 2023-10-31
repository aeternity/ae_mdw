defmodule AeMdwWeb.StatsController do
  use AeMdwWeb, :controller

  alias AeMdw.Miners
  alias AeMdw.Stats
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Util
  alias Plug.Conn

  @statistics_limit 1_000

  plug PaginatedPlug when action not in ~w(transactions_statistics blocks_statistics)a

  plug PaginatedPlug,
       [max_limit: @statistics_limit]
       when action in ~w(transactions_statistics blocks_statistics)a

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

  @spec miners(Conn.t(), map()) :: Conn.t()
  def miners(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    {prev_cursor, miners, next_cursor} = Miners.fetch_miners(state, pagination, cursor)

    Util.paginate(conn, prev_cursor, miners, next_cursor)
  end

  @spec transactions_statistics(Conn.t(), map()) :: Conn.t()
  def transactions_statistics(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_statistics} <-
           Stats.fetch_transactions_statistics(state, pagination, query, scope, cursor) do
      Util.paginate(conn, paginated_statistics)
    end
  end

  @spec blocks_statistics(Conn.t(), map()) :: Conn.t()
  def blocks_statistics(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_statistics} <-
           Stats.fetch_blocks_statistics(state, pagination, query, scope, cursor) do
      Util.paginate(conn, paginated_statistics)
    end
  end

  @spec names_statistics(Conn.t(), map()) :: Conn.t()
  def names_statistics(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_statistics} <-
           Stats.fetch_names_statistics(state, pagination, query, scope, cursor) do
      Util.paginate(conn, paginated_statistics)
    end
  end
end
