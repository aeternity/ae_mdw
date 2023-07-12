defmodule AeMdwWeb.Plugs.VersioningPlug do
  @moduledoc """
  Enables/disables V3 version routes based on config.
  """

  alias AeMdw.Error.Input
  alias AeMdwWeb.Util
  alias Plug.Conn

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Conn.t(), Plug.opts()) :: Conn.t()
  def call(%Conn{request_path: "/v3" <> _path_rest} = conn, _opts) do
    if Application.fetch_env!(:ae_mdw, :enable_v3?) do
      conn
    else
      Util.send_error(conn, Input.NotFound, "no such route")
    end
  end

  def call(conn, _opts), do: conn
end
