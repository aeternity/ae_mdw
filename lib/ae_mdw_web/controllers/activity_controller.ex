defmodule AeMdwWeb.ActivityController do
  use AeMdwWeb, :controller

  alias AeMdw.Activities
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec account_activities(Conn.t(), map()) :: Conn.t()
  def account_activities(%Conn{assigns: assigns} = conn, %{"id" => account}) do
    %{state: state, pagination: pagination, cursor: cursor, query: query, scope: scope} = assigns

    with {:ok, prev_cursor, activities, next_cursor} <-
           Activities.fetch_account_activities(
             state,
             account,
             pagination,
             scope,
             query,
             cursor
           ) do
      Util.paginate(conn, prev_cursor, activities, next_cursor)
    end
  end
end
