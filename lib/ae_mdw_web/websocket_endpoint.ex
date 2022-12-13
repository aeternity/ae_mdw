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

  socket "/websocket", AeMdwWeb.Websocket.SocketHandler,
    websocket: [
      connect_info: [session: @session_options],
      path: "/",
      timeout: 660_000,
      max_frame_size: 128_000
    ]

  socket "/v2/websocket", AeMdwWeb.Websocket.SocketHandler,
    websocket: [
      connect_info: [session: @session_options],
      path: "/",
      timeout: 660_000,
      max_frame_size: 128_000
    ]
end
