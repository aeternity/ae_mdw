# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

mdw_revision =
  case File.read("AEMDW_REVISION") do
    {:ok, revision} ->
      String.trim(revision)

    {:error, :enoent} ->
      {revision, 0} = System.cmd("git", ["log", "-1", "--format=%h"])
      String.trim(revision)
  end

config :ae_mdw, build_revision: mdw_revision

node_root = System.get_env("NODEROOT", "../aeternity/_build/local/")

config :ae_mdw, AeMdw.Db.RocksDb, data_dir: "#{node_root}/rel/aeternity/data/mdw.db"

config :ae_plugin,
  node_root: node_root,
  "$aec_db_create_tables": {AeMdw.Db.NodeStub, :create_tables},
  "$aec_db_check_tables": {AeMdw.Db.NodeStub, :check_tables}

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
  live_view: [signing_salt: "Oy680JAN"]

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

# Configures Elixir's Logger
config :logger,
  backends: [{LoggerFileBackend, :info}, {LoggerFileBackend, :sync}]

config :logger, :info,
  path: "#{Path.join(File.cwd!(), "log/info.log")}",
  format: "$date $time $metadata[$level] $message\n",
  sync_threshold: 100

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
