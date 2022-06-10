defmodule AeMdwWeb.UtilController do
  @moduledoc """
  Endpoint for observing Mdw state.
  """
  use AeMdwWeb, :controller

  alias AeMdw.Db.Status
  alias Plug.Conn

  @spec status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def status(%Conn{assigns: %{state: state}} = conn, _params),
    do: json(conn, Status.node_and_mdw_status(state))

  @spec no_route(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def no_route(conn, _params),
    do: conn |> AeMdwWeb.Util.send_error(404, "no such route")
end
