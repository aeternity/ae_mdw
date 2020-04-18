defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  alias AeMdwWeb.{IpBrowserPlug, DataOffsetPlug}

  pipeline :api do
    plug CORSPlug, origin: "*"
    plug IpBrowserPlug
    plug DataOffsetPlug
    plug :accepts, ["json"]
  end

  scope "/middleware", AeMdwWeb do
    pipe_through :api

    get "/channels/active", ChannelController, :active_channels
    get "/channels/transactions/address/:address", ChannelController, :channel_tx

    get "/oracles/list", OracleController, :all_oracles
    get "/oracles/:oracle_id", OracleController, :oracle_data

    get "/contracts/all", ContractController, :all_contracts
    get "/contracts/transactions/address/:address", ContractController, :contract_tx
    get "/contracts/calls/address/:address", ContractController, :contract_address_calls
    # get "/contracts/transactions/creation/address/{address}" TODO: missing
    post "/contracts/verify", ContractController, :verify_contract

    get "/names", NameController, :all_names
    get "/names/:name", NameController, :search_name
    get "/names/active", NameController, :active_names
    get "/names/auctions/active", NameController, :active_name_auctions
    get "/names/auctions/active/count", NameController, :active_name_auctions_count
    get "/names/auctions/bids/account/:account", NameController, :name_auctions_bids_by_address
    get "/names/auctions/bids/:name", NameController, :name_auctions_bids_by_name
    get "/names/reverse/:account", NameController, :name_by_address
    get "/names/auctions/:name/info", NameController, :auction_info
    get "/names/hash/:hash", NameController, :name_for_hash

    get "/transactions/account/:address/count", TransactionController, :tx_count_by_address
    get "/transactions/account/:sender/to/:receiver", TransactionController, :tx_between_address
    get "/transactions/account/:account", TransactionController, :tx_by_account
    get "/transactions/interval/:from/:to", TransactionController, :tx_by_generation_range
    get "/transactions/rate/:from/:to", TransactionController, :tx_rate_by_date_range

    get "/generations/:from/:to", GenerationController, :generations_by_range

    get "/compilers", UtilController, :compilers
    get "/height/at/:milliseconds", UtilController, :height_by_time
    get "/reward/height/:height", UtilController, :reward_at_height
    get "/size/current", UtilController, :chain_size
    get "/size/height/:height", UtilController, :size_at_height
    get "/status", UtilController, :mdw_status
    get "/count/current", UtilController, :current_tx_count

    # get "/count/height/:height", :count
    # get "/micro-blocks/hash/:hash/transactions/count", :transaction_count_in_micro_block
    # get "/contracts/transactions/creation/address/:address, :creation_tx_for_contract_address
    # get "/new/generations/:from/:to, :generations_by_range2
  end

  scope "/v2", AeMdwWeb do
    pipe_through :api

    get "/transactions/:hash", AeNodeController, :tx_by_hash
    get "/generations/current", AeNodeController, :current_generations
    get "/generations/height/:height", AeNodeController, :generation_by_height
    get "/key-blocks/current/height", AeNodeController, :current_key_block_height
    get "/key-blocks/hash/:hash", AeNodeController, :key_block_by_hash
    get "/key-blocks/height/:height", AeNodeController, :key_block_by_height
    get "/micro-blocks/hash/:hash/header", AeNodeController, :micro_block_header_by_hash

    get "/micro-blocks/hash/:hash/transactions",
        AeNodeController,
        :micro_block_transactions_by_hash

    get "/micro-blocks/hash/:hash/transactions/count",
        AeNodeController,
        :micro_block_transactions_count_by_hash

    get "/accounts/:account", AeNodeController, :get_account_details
  end

  scope "/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :ae_mdw,
      swagger_file: "swagger.json",
      disable_validator: true
  end

  def swagger_info do
    %{
      basePath: "/middleware",
      schemes: ["http"],
      consumes: ["application/json"],
      produces: ["application/json"],
      info: %{
        version: "1.0",
        title: "Aeternity Middleware",
        description: "API for [Aeternity Middleware](https://github.com/aeternity/ae_mdw)"
      }
    }
  end
end
