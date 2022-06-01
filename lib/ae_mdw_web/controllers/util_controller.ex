defmodule AeMdwWeb.UtilController do
  @moduledoc """
  Endpoint for observing Mdw state.
  """
  use AeMdwWeb, :controller

  alias AeMdw.Db.Status

  @spec status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def status(conn, _params),
    do: json(conn, Status.node_and_mdw_status())

  @spec no_route(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def no_route(conn, _params),
    do: conn |> AeMdwWeb.Util.send_error(404, "no such route")
end
