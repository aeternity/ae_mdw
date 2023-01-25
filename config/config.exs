# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ae_mdw, sync: false

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
  contract_cache_expiration_minutes: 1440

# Configures the endpoint
config :ae_mdw, AeMdwWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "kATf71kudJsgA1dgCQKcmgelicqJHG8EID8rwROwJHpWHb53EdzW7YDclJZ8mxLP",
  render_errors: [view: AeMdwWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: AeMdw.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "Oy680JAN"],
  code_reloader: false,
  watchers: [],
  check_origin: false

config :ae_mdw, AeMdwWeb.WebsocketEndpoint,
  code_reloader: false,
  watchers: [],
  check_origin: false

# Configures Elixir's Logger
config :logger,
  backends: [{LoggerFileBackend, :info}, {LoggerFileBackend, :sync}]

config :logger, :info,
  path: "#{Path.join(File.cwd!(), "log/info.log")}",
  metadata: [:request_id],
  format: "$date $time $metadata[$level] $message\n",
  sync_threshold: 100

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
