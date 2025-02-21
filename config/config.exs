import Config

# Database
alias AeMdw.Db.Model

node_root = System.get_env("NODEROOT", "../aeternity/_build/local/")

config :esbuild,
  version: "0.8.2"

config :ae_mdw, AeMdw.Db.RocksDb,
  data_dir: "#{node_root}/data/mdw.db",
  drop_tables: [
    Model.AsyncTasks,
    Model.Aex9Balance,
    Model.Aex9Transfer,
    Model.RevAex9Transfer,
    Model.Aex9PairTransfer,
    Model.IdxAex9Transfer,
    Model.IdxAex9AccountPresence
  ]

# Sync
config :ae_plugin,
  node_root: node_root,
  "$aec_db_create_tables": {AeMdw.Db.NodeStub, :create_tables},
  "$aec_db_check_tables": {AeMdw.Db.NodeStub, :check_tables}

config :ae_mdw,
  sync: true,
  contract_cache_expiration_minutes: 60,
  endpoint_timeout: 50_000

# Endpoints
config :ae_mdw, AeMdwWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "kATf71kudJsgA1dgCQKcmgelicqJHG8EID8rwROwJHpWHb53EdzW7YDclJZ8mxLP",
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: AeMdwWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AeMdw.PubSub,
  live_view: [signing_salt: "Oy680JAN"],
  code_reloader: false,
  watchers: [],
  check_origin: false

config :ae_mdw, AeMdwWeb.WebsocketEndpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: AeMdwWeb.ErrorJSON],
    layout: false
  ],
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

# active entities
config :ae_mdw, AeMdw.Entities,
  nft_auction: %{
    initial: "put_listing",
    final: ["cancel_listing", "accept_offer"]
  }

config :ae_mdw, AeMdw.EntityCalls, %{
  "put_listing" => [:contract, :int, :int],
  "cancel_listing" => [:contract, :int],
  "accept_offer" => [:contract, :int]
}

# dex
config :ae_mdw, :dex_factories, %{
  # "ct_2mfj3FoZxnhkSw5RZMcP8BfPoB1QR4QiYGNCdkAvLZ1zfF6paW"
  "ae_mainnet" =>
    <<233, 30, 151, 180, 233, 65, 226, 183, 109, 12, 219, 231, 56, 176, 122, 108, 140, 46, 55,
      120, 136, 137, 108, 10, 214, 208, 33, 75, 126, 14, 243, 174>>,
  # "ct_NhbxN8wg8NLkGuzwRNDQhMDKSKBwDAQgxQawK7tkigi2aC7i9"
  "ae_uat" =>
    <<49, 69, 201, 179, 64, 73, 251, 153, 205, 37, 147, 13, 132, 58, 150, 207, 81, 149, 186, 147,
      107, 208, 117, 185, 160, 135, 239, 247, 134, 40, 7, 80>>
}

config :ae_mdw, :ae_token, %{
  # "ct_J3zBY8xxjsRr3QojETNw48Eb38fjvEuJKkQ6KzECvubvEcvCa"
  "ae_mainnet" =>
    <<38, 183, 172, 84, 94, 51, 242, 135, 60, 130, 44, 59, 52, 52, 110, 37, 13, 210, 14, 54, 144,
      24, 53, 177, 117, 211, 247, 18, 109, 117, 189, 41>>,
  # "ct_JDp175ruWd7mQggeHewSLS1PFXt9AzThCDaFedxon8mF8xTRF"
  "ae_uat" =>
    <<39, 26, 34, 124, 164, 250, 243, 90, 198, 12, 74, 70, 137, 147, 70, 150, 174, 68, 138, 188,
      64, 12, 26, 227, 206, 15, 221, 211, 50, 4, 47, 82>>
}

import_config "#{Mix.env()}.exs"
