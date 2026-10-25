defmodule AeMdwWeb.MinerStatsController do
  use AeMdwWeb, :controller

  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.MinerStats
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  @max_limit 1_000

  plug(
    PaginatedPlug,
    max_limit: @max_limit,
    order_by: [:blocks, :txs, :rewards, :fees, :first_active, :last_active]
  )

  action_fallback(FallbackController)

  @spec summary(Conn.t(), map()) :: Conn.t()
  def summary(%Conn{assigns: %{state: state}} = conn, _params) do
    with {:ok, summary} <- MinerStats.fetch_summary(state) do
      format_json(conn, summary)
    end
  end

  @spec miners(Conn.t(), map()) :: Conn.t()
  def miners(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, order_by: order_by, cursor: cursor} =
      assigns

    with {:ok, paginated} <- MinerStats.fetch_miners(state, pagination, query, order_by, cursor) do
      Util.render(conn, paginated)
    end
  end

  @spec miner(Conn.t(), map()) :: Conn.t()
  def miner(%Conn{assigns: %{state: state, query: query}} = conn, %{"id" => id}) do
    with {:ok, miner} <- MinerStats.fetch_miner(state, query, id) do
      format_json(conn, miner)
    end
  end

  @spec links(Conn.t(), map()) :: Conn.t()
  def links(%Conn{assigns: assigns} = conn, %{"id" => id}) do
    %{state: state, pagination: pagination, query: query, cursor: cursor} = assigns

    with {:ok, paginated} <- MinerStats.fetch_links(state, pagination, query, id, cursor) do
      Util.render(conn, paginated)
    end
  end

  @spec miner_series(Conn.t(), map()) :: Conn.t()
  def miner_series(%Conn{assigns: assigns} = conn, %{"id" => id}) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, scope} <- gen_scope(scope),
         {:ok, paginated} <-
           MinerStats.fetch_miner_series(state, pagination, id, scope, query, cursor) do
      Util.render(conn, paginated)
    end
  end

  @spec network_series(Conn.t(), map()) :: Conn.t()
  def network_series(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, query: query, scope: scope, cursor: cursor} = assigns

    with {:ok, scope} <- gen_scope(scope),
         {:ok, paginated} <-
           MinerStats.fetch_network_series(state, pagination, scope, query, cursor) do
      Util.render(conn, paginated)
    end
  end

  @spec bucket(Conn.t(), map()) :: Conn.t()
  def bucket(%Conn{assigns: %{state: state}} = conn, %{"bucket" => bucket}) do
    with {:ok, bucket} <- MinerStats.parse_bucket(bucket),
         {:ok, bucket_stats} <- MinerStats.fetch_bucket(state, bucket) do
      format_json(conn, bucket_stats)
    end
  end

  @spec bucket_miners(Conn.t(), map()) :: Conn.t()
  def bucket_miners(%Conn{assigns: assigns} = conn, %{"bucket" => bucket}) do
    %{state: state, pagination: pagination, query: query, cursor: cursor} = assigns

    with {:ok, bucket} <- MinerStats.parse_bucket(bucket),
         {:ok, paginated} <-
           MinerStats.fetch_bucket_miners(state, pagination, bucket, query, cursor) do
      Util.render(conn, paginated)
    end
  end

  defp gen_scope(nil), do: {:ok, nil}
  defp gen_scope({:gen, _range} = scope), do: {:ok, scope}

  defp gen_scope({_scope_type, range}),
    do: {:error, ErrInput.Scope.exception(value: inspect(range))}
end
