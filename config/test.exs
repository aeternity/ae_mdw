import Config

# ae_plugin reads the node's sys.config at startup and applies it with
# application:set_env, which overwrites anything set in Mix config.
# We use a setup hook at phase 999 (just before aecore's set_app_ctrl_mode
# hook at phase 1000) to re-apply maintenance mode, preventing aesync from
# starting and causing "Timeout adding_synced block" crashes mid-test-run.
config :ae_mdw, :"$setup_hooks", [
  {:normal, [{999, {AeMdw.AecoreTestConfig, :configure, []}}]}
]

# Sync
config :ae_mdw,
  sync: false,
  endpoint_timeout: 500,
  # Do not start aecore node services (aehttp/aesync/...) in tests. Combined with
  # app_ctrl maintenance mode (see AeMdw.Application), this keeps aesync from
  # syncing and crashing the node mid-suite ("Timeout adding_synced block"), which
  # would erase the {:aec_db, *} persistent_terms and cause flaky test failures.
  start_node_services: false

# Enable the MDW Block-index scan fallback for block-hash lookups. In tests,
# fixtures populate the index without node-DB entries and a syncing node can
# transiently lag the index, so this fallback is needed. Disabled in production
# to avoid O(chain_length) scans on unknown hashes (a DoS vector).
config :ae_mdw, scan_block_state_fallback: true

# Telemetry
config :ae_mdw, TelemetryMetricsStatsd,
  host: "localhost",
  port: 8115

if System.get_env("INTEGRATION_TEST") != "1" do
  # Database
  config :ae_mdw, AeMdw.Db.RocksDb, data_dir: "test_data.db"
end

# HTTP
protocol_opts = [max_request_line_length: 1_024]

config :ae_mdw, AeMdwWeb.Endpoint,
  http: [
    port: 4002,
    http_1_options: protocol_opts,
    http_2_options: [enabled: true]
  ],
  server: false

config :ae_mdw, AeMdwWeb.WebsocketEndpoint,
  http: [
    port: 4003,
    http_1_options: protocol_opts,
    http_2_options: [enabled: true],
    thousand_island_options: [read_timeout: 30 * :timer.seconds(60)]
  ],
  server: true

config :ae_mdw, AeMdwWeb.Websocket.Subscriptions,
  max_subs_per_conn: 10,
  max_connections_per_ip: 10_000,
  max_total_connections: 10_000,
  max_total_subs: 10_000_000

# Logging
config :logger, level: :warn

# Stat
config :ae_mdw, build_revision: "abcd1234"

config :logger_json, :backend,
  metadata: [:request_id],
  json_encoder: Jason,
  metadata_formatter: LoggerJSON.Plug.MetadataFormatters.DatadogLogger,
  formatter: LoggerJSON.Formatters.DatadogLogger

# Custom events rendering
config :ae_mdw, AeMdwWeb.LogsView,
  custom_events_args: %{
    "Listing" => %{0 => :contract_pubkey},
    "Offer" => %{1 => :contract_pubkey},
    "Trade" => %{2 => :contract_pubkey}
  }

# Disable GraphQL response cache during tests to preserve test isolation.
config :ae_mdw, :graphql_response_cache_ttl_ms, 0
