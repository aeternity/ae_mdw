import Config

config :ae_mdw, build_revision: String.trim(File.read!("AEMDW_REVISION"))

# Logging
config :logger,
  level: :info,
  backends: [{LoggerFileBackend, :info}]

# phoenix
config :phoenix, :serve_endpoints, true
