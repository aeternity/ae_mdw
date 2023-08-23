defmodule AeMdwWeb.ActiveEntityController do
  @moduledoc false
  use AeMdwWeb, :controller

  alias AeMdw.ActiveEntities
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec active_entities(Conn.t(), map()) :: Conn.t()
  def active_entities(%Conn{assigns: assigns} = conn, %{"id" => type}) do
    %{state: state, pagination: pagination, query: query, cursor: cursor, scope: scope} = assigns
    query = Map.put(query, "type", type)

    with {:ok, entities} <-
           ActiveEntities.fetch_entities(state, pagination, scope, query, cursor) do
      Util.paginate(conn, entities)
    end
  end
end
