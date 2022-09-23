defmodule AeMdwWeb.SwaggerForward do
  @moduledoc """
  Redirects to the static html of the respective swagger version yaml file.
  """
  use AeMdwWeb, :controller

  def index_v1(conn, _params) do
    redirect(conn, to: "/swagger/index_v1.html")
  end

  def index_v2(conn, _params) do
    redirect(conn, to: "/swagger/index_v2.html")
  end
end
