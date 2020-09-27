defmodule AeMdwWeb.WebPageController do
  use AeMdwWeb, :controller

  @frontend_entrypoint "priv/static/frontend/index.html"
  def index(conn, _params) do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> Plug.Conn.send_file(200, @frontend_entrypoint)
    |> halt()
  end
end
