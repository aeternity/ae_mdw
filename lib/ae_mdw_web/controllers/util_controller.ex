defmodule AeMdwWeb.UtilController do
  @moduledoc """
  Endpoint for observing Mdw state.
  """
  use AeMdwWeb, :controller

  alias AeMdw.Db.Status
  alias AeMdw.Error.Input
  alias Plug.Conn

  @spec status(Conn.t(), map()) :: Conn.t()
  def status(%Conn{assigns: %{state: state}} = conn, _params),
    do: json(conn, Status.node_and_mdw_status(state))

  @spec no_route(Conn.t(), map()) :: Conn.t()
  def no_route(conn, _params),
    do: AeMdwWeb.Util.send_error(conn, Input.NotFound, "no such route")

  @spec static_file(Conn.t(), map()) :: Conn.t()
  def static_file(%Conn{assigns: %{filepath: filepath}} = conn, _params) do
    filepath = Application.app_dir(:ae_mdw, Path.join("priv", filepath))

    send_file(conn, 200, filepath)
  end
end
