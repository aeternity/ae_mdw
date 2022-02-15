use Mix.Config

# Sync
config :ae_mdw, sync: false

data_dir =
  if System.get_env("INTEGRATION_TEST") do
    "data.db"
  else
    "test_data.db"
  end

# Database
config :ae_mdw, AeMdw.Db.RocksDb,
  data_dir: data_dir

# HTTP
config :ae_mdw, AeMdwWeb.Endpoint,
  http: [port: 4002],
  server: false

# Log warnings
config :logger, level: :warn
