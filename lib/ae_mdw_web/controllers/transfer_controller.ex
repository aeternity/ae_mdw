defmodule AeMdwWeb.TransferController do
  use AeMdwWeb, :controller

  alias AeMdw.Transfers
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)

  @spec transfers(Conn.t(), map()) :: Conn.t()
  def transfers(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    %{pagination: pagination, cursor: cursor, scope: scope} = assigns

    case Transfers.fetch_transfers(pagination, scope, query_params, cursor) do
      {:ok, prev_cursor, transfers, next_cursor} ->
        Util.paginate(conn, prev_cursor, transfers, next_cursor)

      {:error, reason} ->
        Util.send_error(conn, :bad_request, reason)
    end
  end
end
