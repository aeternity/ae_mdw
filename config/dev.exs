import Config

# Telemetry
config :ae_mdw, :enable_livedashboard, true

config :ae_mdw, TelemetryMetricsStatsd,
  host: "localhost",
  port: 8125

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
