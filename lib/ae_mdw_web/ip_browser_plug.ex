defmodule AeMdwWeb.IpBrowserPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> assign(:peer_ip, conn.remote_ip)
    |> assign(:browser_info, find_user_agent(conn))
  end

  defp find_user_agent(conn) do
    case Enum.find(conn.req_headers, fn x -> elem(x, 0) == "user-agent" end) do
      data -> elem(data, 1)
      nil -> "Other"
    end
  end
end
