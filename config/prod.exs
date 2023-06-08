import Config

# Stat
{revision, 0} = System.cmd("git", ["log", "-1", "--format=%h"])
config :ae_mdw, build_revision: String.trim(revision)

# Logging
config :logger,
  level: :info,
  backends: [{LoggerFileBackend, :info}]

# phoenix
config :phoenix, :serve_endpoints, true
