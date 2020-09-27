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
    at: "/",
    from: {:ae_mdw, "priv/static/frontend"},
    gzip: false,
    only:
      ~w(index.html 200.html favicon.ico robots.txt channels faucet generations names oracles transactions auctions contracts _nuxt)

  plug Plug.Static,
    at: "/swagger",
    from: {:ae_mdw, "priv/static"},
    gzip: false,
    only: ~w(swagger.json)

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
