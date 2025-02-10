import Config

# Sync
config :ae_mdw,
  sync: false,
  endpoint_timeout: 500

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

# Custom events rendering
config :ae_mdw, AeMdwWeb.LogsView,
  custom_events_args: %{
    "Listing" => %{0 => :contract_pubkey},
    "Offer" => %{1 => :contract_pubkey},
    "Trade" => %{2 => :contract_pubkey}
  }
