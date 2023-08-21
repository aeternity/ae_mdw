defmodule AeMdwWeb.TransferController do
  use AeMdwWeb, :controller

  alias AeMdw.Transfers
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec transfers(Conn.t(), map()) :: Conn.t()
  def transfers(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query} = assigns

    with {:ok, paginated_transfers} <-
           Transfers.fetch_transfers(state, pagination, scope, query, cursor) do
      Util.paginate(conn, paginated_transfers)
    end
  end
end
