defmodule AeMdwWeb.UtilController do
  @moduledoc """
  Endpoint for observing Mdw state.
  """
  use AeMdwWeb, :controller

  alias AeMdw.Db.Status
  alias AeMdw.Error.Input
  alias Plug.Conn

  @spec status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def status(%Conn{assigns: %{state: state}} = conn, _params),
    do: json(conn, Status.node_and_mdw_status(state))

  @spec no_route(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def no_route(conn, _params),
    do: AeMdwWeb.Util.send_error(conn, Input.NotFound, "no such route")
end
