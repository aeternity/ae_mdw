defmodule AeMdwWeb.PageController do
  use AeMdwWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
