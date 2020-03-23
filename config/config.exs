# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :ae_plugin,
  node_root: "../aeternity/_build/local/",
  "$aec_db_create_tables": {AeMdw.Db.Setup, :create_tables},
  "$aec_db_check_tables": {AeMdw.Db.Setup, :check_tables}

# Configures the endpoint
config :ae_mdw, AeMdwWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "kATf71kudJsgA1dgCQKcmgelicqJHG8EID8rwROwJHpWHb53EdzW7YDclJZ8mxLP",
  render_errors: [view: AeMdwWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: AeMdw.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "Oy680JAN"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
