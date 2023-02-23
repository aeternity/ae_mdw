import Config

config :ae_mdw, build_revision: String.trim(File.read!("AEMDW_REVISION"))

# Endpoint
port = String.to_integer(System.get_env("PORT") || "4000")

config :ae_mdw, AeMdwWeb.Endpoint,
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: port
  ],
  cache_static_manifest: "priv/static/cache_manifest.json"

ws_port = String.to_integer(System.get_env("WS_PORT") || "4001")

config :ae_mdw, AeMdwWeb.WebsocketEndpoint,
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: ws_port
  ]

# Logging
config :logger,
  level: :info,
  backends: [{LoggerFileBackend, :info}]
