defmodule AeMdwWeb.WebsocketEndpoint do
  @moduledoc """
  Endpoint to allow websocket listening to custom port different form HTTP.
  """
  use Phoenix.Endpoint, otp_app: :ae_mdw

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_ae_mdw_ws_key",
    signing_salt: "1cOf/zsp"
  ]

  # Idle timeout matches a typical 3-hour reverse-proxy keepalive window.
  # Clients should send Ping every ~10 minutes to keep the proxy connection alive.
  @ws_idle_timeout 10_800_000

  socket "/websocket", AeMdwWeb.Websocket.SocketHandler,
    websocket: [
      connect_info: [session: @session_options, peer_data: [], version: :v1],
      path: "/",
      timeout: @ws_idle_timeout,
      max_frame_size: 128_000
    ]

  socket "/v2/websocket", AeMdwWeb.Websocket.SocketHandler,
    websocket: [
      connect_info: [session: @session_options, peer_data: [], version: :v2],
      path: "/",
      timeout: @ws_idle_timeout,
      max_frame_size: 128_000
    ]

  socket "/v3/websocket", AeMdwWeb.Websocket.SocketHandler,
    websocket: [
      connect_info: [session: @session_options, peer_data: [], version: :v3],
      path: "/",
      timeout: @ws_idle_timeout,
      max_frame_size: 128_000
    ]
end
