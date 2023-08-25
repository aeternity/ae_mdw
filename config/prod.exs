import Config

config :ae_mdw, build_revision: String.trim(File.read!("AEMDW_REVISION"))

# Logging
config :logger,
  level: :info,
  backends: [{LoggerFileBackend, :info}]

# phoenix
config :phoenix, :serve_endpoints, true

# NFT Marketplaces
config :ae_mdw, AeMdw.Entities,
  nft_auction: %{
    initial: "put_listing",
    final: ["cancel_listing", "accept_offer"]
  }

config :ae_mdw, AeMdw.EntityCalls,
  put_listing: ["address", "int", "int"],
  cancel_listing: ["address", "int"],
  accept_offer: ["address", "int"]
