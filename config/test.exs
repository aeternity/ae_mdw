import Config

# Sync
config :ae_mdw, sync: false

# Telemetry
config :ae_mdw, TelemetryMetricsStatsd,
  host: "localhost",
  port: 8115

if System.get_env("INTEGRATION_TEST") != "1" do
  # Database
  config :ae_mdw, AeMdw.Db.RocksDb, data_dir: "test_data.db"
end

config :aecore, network_id: System.get_env("NETWORK_ID", "ae_mainnet")

# HTTP
config :ae_mdw, AeMdwWeb.Endpoint,
  http: [port: 4002],
  server: false

config :ae_mdw, AeMdwWeb.WebsocketEndpoint,
  http: [
    port: 4003,
    protocol_options: [max_request_line_length: 1_024, max_skip_body_length: 1_024]
  ],
  server: true

config :ae_mdw, AeMdwWeb.Websocket.Subscriptions, max_subs_per_conn: 10

# Logging
config :logger, level: :warn

config :logger,
  backends: [{LoggerFileBackend, :info}]

# Stat
config :ae_mdw, build_revision: "abcd1234"

config :logger_json, :backend,
  metadata: [:request_id],
  json_encoder: Jason,
  metadata_formatter: LoggerJSON.Plug.MetadataFormatters.DatadogLogger,
  formatter: LoggerJSON.Formatters.DatadogLogger
