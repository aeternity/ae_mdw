# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :ae_plugin,
  node_root: System.get_env("NODEROOT", "../aeternity/_build/local/"),
  "$aec_db_create_tables": {AeMdw.Db.Setup, :create_tables},
  "$aec_db_check_tables": {AeMdw.Db.Setup, :check_tables}

config :ae_mdw,
  sync: true,
  # email address where to send sync crash notification
  operators: [],
  contract_cache_expiration_minutes: 1440

# Configures the endpoint
config :ae_mdw, AeMdwWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "kATf71kudJsgA1dgCQKcmgelicqJHG8EID8rwROwJHpWHb53EdzW7YDclJZ8mxLP",
  render_errors: [view: AeMdwWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: AeMdw.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "Oy680JAN"],
  continuation_cache_expiration_minutes: 30,
  # 5 days default generations cache expiration
  generations_cache_expiration_minutes: 7200

config :ae_mdw, AeWebsocket.Websocket.SocketHandler,
  port: 4001,
  path: "/websocket",
  # don't accept connections if server already has this number of connections
  max_connections: 10000,
  # force to disconnect a connection if the duration passed. if :infinity is set, do nothing.
  max_connection_age: :infinity,
  # disconnect if no event comes on a connection during this duration
  idle_timeout: :infinity,
  # TCP SO_REUSEPORT flag
  reuse_port: false,
  show_debug_logs: false,
  transmission_limit: [
    # if 1000 frames are sent on a connection
    capacity: 1000,
    # in 2 seconds, disconnect it.
    duration: 2000
  ]

config :ae_mdw, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      router: AeMdwWeb.Router
    ]
  }

config :phoenix_swagger, json_library: Jason

# Configures Elixir's Logger
config :logger,
  backends: [{LoggerFileBackend, :info}, {LoggerFileBackend, :sync}]

config :logger, :info,
  path: "#{Path.join(File.cwd!(), "log/info.log")}",
  format: "$time $metadata[$level] $message\n"

config :logger, :sync,
  path: "#{Path.join(File.cwd!(), "log/sync.log")}",
  metadata_filter: [sync: true]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
