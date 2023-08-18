defmodule AeMdwWeb.TransferController do
  use AeMdwWeb, :controller

  alias AeMdw.Transfers
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)

  @spec transfers(Conn.t(), map()) :: Conn.t()
  def transfers(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    transfers = Transfers.fetch_transfers(state, pagination, scope, query_params, cursor)
    Util.paginate(conn, transfers)
  end
end
