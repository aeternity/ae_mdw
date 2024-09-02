defmodule AeMdwWeb.StatsController do
  use AeMdwWeb, :controller

  alias AeMdw.Miners
  alias AeMdw.Stats
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Util
  alias Plug.Conn

  @stats_limit 1_000

  plug PaginatedPlug when action not in ~w(transactions_stats blocks_stats names_stats)a

  plug PaginatedPlug,
       [max_limit: @stats_limit]
       when action in ~w(transactions_stats blocks_stats names_stats)a

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

    Util.render(conn, prev_cursor, stats, next_cursor)
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

    Util.render(conn, prev_cursor, stats, next_cursor)
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

    Util.render(conn, prev_cursor, stats, next_cursor)
  end

  @spec stats(Conn.t(), map()) :: Conn.t()
  def stats(%Conn{assigns: %{state: state}} = conn, _params) do
    case Stats.fetch_stats(state) do
      {:ok, stats} -> format_json(conn, stats)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec miners_stats(Conn.t(), map()) :: Conn.t()
  def miners_stats(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    {prev_cursor, miners, next_cursor} = Miners.fetch_miners(state, pagination, cursor)

    Util.render(conn, prev_cursor, miners, next_cursor)
  end

  @spec transactions_stats(Conn.t(), map()) :: Conn.t()
  def transactions_stats(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_stats} <-
           Stats.fetch_transactions_stats(state, pagination, query, scope, cursor) do
      Util.render(conn, paginated_stats)
    end
  end

  @spec blocks_stats(Conn.t(), map()) :: Conn.t()
  def blocks_stats(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_stats} <-
           Stats.fetch_blocks_stats(state, pagination, query, scope, cursor) do
      Util.render(conn, paginated_stats)
    end
  end

  @spec difficulty_stats(Conn.t(), map()) :: Conn.t()
  def difficulty_stats(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_stats} <-
           Stats.fetch_difficulty_stats(state, pagination, query, scope, cursor) do
      Util.render(conn, paginated_stats)
    end
  end

  @spec hashrate_stats(Conn.t(), map()) :: Conn.t()
  def hashrate_stats(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_stats} <-
           Stats.fetch_hashrate_stats(state, pagination, query, scope, cursor) do
      Util.render(conn, paginated_stats)
    end
  end

  @spec aex9_token_transfers_stats(Conn.t(), map()) :: Conn.t()
  def aex9_token_transfers_stats(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_stats} <-
           Stats.fetch_aex9_token_transfers_stats(state, pagination, query, scope, cursor) do
      Util.render(conn, paginated_stats)
    end
  end

  @spec names_stats(Conn.t(), map()) :: Conn.t()
  def names_stats(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_stats} <-
           Stats.fetch_names_stats(state, pagination, query, scope, cursor) do
      Util.render(conn, paginated_stats)
    end
  end

  @spec contracts_stats(Conn.t(), map()) :: Conn.t()
  def contracts_stats(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_stats} <-
           Stats.fetch_contracts_stats(state, pagination, query, scope, cursor) do
      Util.render(conn, paginated_stats)
    end
  end
end
