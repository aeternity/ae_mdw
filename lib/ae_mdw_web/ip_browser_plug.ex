defmodule AeMdwWeb.IpBrowserPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> assign(:peer_ip, conn.remote_ip)
    |> assign(:browser_info, Browser.full_display(conn))
  end
end
