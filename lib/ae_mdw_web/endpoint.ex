defmodule AeMdwWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ae_mdw

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_ae_mdw_key",
    signing_salt: "0cOe/zsp"
  ]

  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.

  plug Plug.Static,
    at: "/swagger",
    from: {:ae_mdw, "priv/static/swagger"},
    gzip: false,
    only: ~w(swagger ui_files index.html swagger_v1.yaml swagger_v2.yaml),
    headers: %{"access-control-allow-origin" => "*"}

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug CORSPlug
  plug AeMdwWeb.Router
end
