defmodule AeMdwWeb.ActivityController do
  use AeMdwWeb, :controller

  alias AeMdw.Activities
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug, txi_scope?: false)
  action_fallback(FallbackController)

  @spec account_activities(Conn.t(), map()) :: Conn.t()
  def account_activities(%Conn{assigns: assigns} = conn, %{"id" => account}) do
    %{state: state, pagination: pagination, cursor: cursor, query: query, scope: scope} = assigns

    with {:ok, paginated_activities} <-
           Activities.fetch_account_activities(
             state,
             account,
             pagination,
             scope,
             query,
             cursor
           ) do
      Util.render(conn, paginated_activities)
    end
  end

  @spec account_counters(Conn.t(), map()) :: Conn.t()
  def account_counters(conn, %{"id" => account}) do
    %{state: state} = conn.assigns

    with {:ok, counters} <-
           Activities.fetch_account_counters(
             state,
             account
           ) do
      json(conn, counters)
    end
  end
end
