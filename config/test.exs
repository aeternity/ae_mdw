import Config

# Sync
config :ae_mdw, sync: false

#
# Telemetry
#
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
  http: [port: 4003],
  server: true

# Log warnings
config :logger, level: :warn
