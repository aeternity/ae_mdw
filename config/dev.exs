import Config

# Chain
config :aecore, network_id: System.get_env("NETWORK_ID", "ae_mainnet")

# Telemetry
config :ae_mdw, :enable_livedashboard, true

config :ae_mdw, TelemetryMetricsStatsd,
  host: "localhost",
  port: 8125

# Endpoints
config :ae_mdw, AeMdwWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  live_view: [signing_salt: "btmQfEtjXdzpKeXzQ1kfVAJmc0gPU/pX"]

config :ae_mdw, AeMdwWeb.WebsocketEndpoint,
  http: [port: 4001],
  debug_errors: true

# Logging
config :logger,
  backends: [{LoggerFileBackend, :info}]

# Phoenix
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# Stat
{revision, 0} = System.cmd("git", ["log", "-1", "--format=%h"])
config :ae_mdw, build_revision: String.trim(revision)

# Dev tools
if File.exists?(Path.join([__DIR__, "dev.tools.exs"])) do
  import_config "dev.tools.exs"
end
