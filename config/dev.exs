import Config

# Chain
config :aecore, network_id: System.get_env("NETWORK_ID", "ae_mainnet")

# Telemetry
config :ae_mdw, :enable_livedashboard, true

config :ae_mdw, TelemetryMetricsStatsd,
  host: "localhost",
  port: 8125

# Endpoints
config :ae_mdw, AeMdwWeb.Endpoint,
  debug_errors: true,
  live_view: [signing_salt: "btmQfEtjXdzpKeXzQ1kfVAJmc0gPU/pX"]

# Logging
config :logger,
  backends: [{LoggerFileBackend, :info}]

# Phoenix
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# Stat
{revision, 0} = System.cmd("git", ["log", "-1", "--format=%h"])
config :ae_mdw, build_revision: String.trim(revision)

# Local active entities
config :ae_mdw, AeMdw.Entities,
  nft_auction: %{
    initial: "put_listing",
    final: ["cancel_listing", "accept_offer"]
  }

config :ae_mdw, AeMdw.EntityCalls,
  put_listing: ["address", "int", "int"],
  cancel_listing: ["address", "int"],
  accept_offer: ["address", "int"]

# Local custom events rendering
config :ae_mdw, AeMdwWeb.LogsView,
  custom_events_args: %{
    "Listing" => %{0 => :contract_pubkey},
    "Cancel" => %{0 => :contract_pubkey},
    "Offer" => %{0 => :contract_pubkey},
    "Trade" => %{0 => :contract_pubkey},
    "Withdraw" => %{0 => :contract_pubkey}
  }

# Dev tools
if File.exists?(Path.join([__DIR__, "dev.tools.exs"])) do
  import_config "dev.tools.exs"
end
