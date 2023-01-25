import Config

config :aecore, network_id: System.get_env("NETWORK_ID", "ae_mainnet")

#
# Telemetry
#
config :ae_mdw, :livedashboard_enabled?, true

config :ae_mdw, TelemetryMetricsStatsd,
  host: "localhost",
  port: 8125

#
# Endpoints
#
config :ae_mdw, AeMdwWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  live_view: [signing_salt: "btmQfEtjXdzpKeXzQ1kfVAJmc0gPU/pX"]

config :ae_mdw, AeMdwWeb.WebsocketEndpoint,
  http: [port: 4001],
  debug_errors: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

if File.exists?(Path.join([__DIR__, "dev.tools.exs"])) do
  import_config "dev.tools.exs"
end
