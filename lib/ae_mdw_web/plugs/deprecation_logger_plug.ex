defmodule AeMdwWeb.Plugs.DeprecationLoggerPlug do
  @moduledoc """
  Logs useful information to detect deprecated endpoint clients.
  """

  alias Plug.Conn
  alias AeMdw.Log

  require Logger

  @updated_prefixes ~w(status v2 v3)

  @spec init([]) :: []
  def init(opts), do: opts

  @spec call(Conn.t(), []) :: Conn.t()
  def call(%Conn{path_info: [path_prefix | _rest]} = conn, _opts)
      when path_prefix in @updated_prefixes,
      do: conn

  def call(%Conn{request_path: request_path, remote_ip: remote_ip} = conn, _opts) do
    referer =
      case Conn.get_req_header(conn, "referer") do
        [referer] -> referer
        _no_match -> :inet.ntoa(remote_ip)
      end

    Log.info("[DEPRECATED] request: `#{request_path}`. referer: #{referer}")

    conn
  end
end
