defmodule AeMdwWeb.SwaggerForward do
  @moduledoc """
  Redirects to the static html of the respective swagger version yaml file.
  """
  use AeMdwWeb, :controller

  alias Plug.Conn

  @spec index_v1(Conn.t(), any()) :: Conn.t()
  def index_v1(%Plug.Conn{path_info: [begin | _path]} = conn, _params) do
    redirect(conn, to: swagger_path(begin, "v1"))
  end

  @spec index_v2(Conn.t(), any()) :: Conn.t()
  def index_v2(%Plug.Conn{path_info: [begin | _path]} = conn, _params) do
    redirect(conn, to: swagger_path(begin, "v2"))
  end

  defp swagger_path(begin, version) do
    prefix = if not String.contains?(begin, "mdw"), do: "/mdw"
    "#{prefix}/swagger/index.html?version=#{version}"
  end
end
