defmodule AeMdwWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ae_mdw

  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.

  plug Plug.Static,
    at: "/swagger",
    from: {:ae_mdw, "priv/static/swagger"},
    gzip: false,
    only: ~w(swagger.json swagger swagger_v1.yaml swagger_v2.json swagger_v3.json),
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
  plug CORSPlug
  plug AeMdwWeb.Router

  socket "/live", Phoenix.LiveView.Socket
end
