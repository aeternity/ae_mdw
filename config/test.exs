import Config

# Sync
config :ae_mdw, sync: false

if System.get_env("INTEGRATION_TEST") != "1" do
  # Database
  config :ae_mdw, AeMdw.Db.RocksDb, data_dir: "test_data.db"
end

# HTTP
config :ae_mdw, AeMdwWeb.Endpoint,
  http: [port: 4002],
  server: false

# Log warnings
config :logger, level: :warn
