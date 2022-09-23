defmodule AeMdwWeb.SwaggerForward do
  @moduledoc """
  Redirects to the static html of the respective swagger version yaml file.
  """
  use AeMdwWeb, :controller

  alias Plug.Conn

  @spec index_v1(Conn.t(), any()) :: Conn.t()
  def index_v1(conn, _params) do
    redirect(conn, to: "/swagger/index_v1.html")
  end

  @spec index_v2(Conn.t(), any()) :: Conn.t()
  def index_v2(conn, _params) do
    redirect(conn, to: "/swagger/index_v2.html")
  end
end
