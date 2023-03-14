import Config

# Database
node_root = System.get_env("NODEROOT", "../aeternity/_build/local/")

config :ae_mdw, AeMdw.Db.RocksDb, data_dir: "#{node_root}/rel/aeternity/data/mdw.db"

# Sync
config :ae_plugin,
  node_root: node_root,
  "$aec_db_create_tables": {AeMdw.Db.NodeStub, :create_tables},
  "$aec_db_check_tables": {AeMdw.Db.NodeStub, :check_tables}

config :ae_mdw,
  sync: true,
  contract_cache_expiration_minutes: 1440

# Endpoints
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

config :ae_mdw, AeMdwWeb.Websocket.Subscriptions, max_subs_per_conn: 10_000

# Logging
config :logger,
  backends: [:console, {LoggerFileBackend, :info}]

config :logger, :info,
  path: "#{Path.join(File.cwd!(), "log/info.log")}",
  metadata: [:request_id],
  format: "$date $time $metadata[$level] $message\n",
  sync_threshold: 100

config :logger_json, :backend, json_encoder: Jason

# API
config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
