defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  alias AeMdwWeb.IpBrowserPlug

  pipeline :api do
    plug CORSPlug, origin: "*"
    plug IpBrowserPlug
    plug :accepts, ["json"]
  end

  scope "/middleware", AeMdwWeb do
    pipe_through :api

    get "/channels/active", ChannelController, :active_channels
    get "/channels/transactions/address/:address", ChannelController, :txs_for_channel_address

    get "/oracles/list", OracleController, :oracles_all
    # seems like there are not registered oracles in aeternal
    get "/oracles/:oracle_id", OracleController, :oracle_requests_responses

    get "/contracts/all", ContractController, :all_contracts
    get "/contracts/transactions/address/:address", ContractController, :txs_for_contract_address
    get "/contracts/calls/address/:address", ContractController, :calls_for_contract_address
    post "/contracts/verify", ContractController, :verify_contract

    get "/names", NameController, :all_names
    get "/names/:name", NameController, :search_names
    get "/names/active", NameController, :active_names
    get "/names/auctions/active", NameController, :active_name_auctions
    get "/names/auctions/active/count", NameController, :active_name_auctions_count
    get "/names/auctions/bids/account/:account", NameController, :bids_for_account
    get "/names/auctions/bids/:name", NameController, :bids_for_name
    get "/names/reverse/:account", NameController, :reverse_names
    get "/names/auctions/:name/info", NameController, :info_for_auction
    get "/names/hash/:hash", NameController, :name_for_hash

    # Not need for the frontend
    get "/transactions/account/:address/count", TransactionController, :txs_count_for_account

    # Not need for the frontend
    get "/transactions/account/:sender/to/:receiver",
        TransactionController,
        :txs_for_account_to_account

    get "/transactions/account/:account", TransactionController, :txs_for_account
    get "/transactions/interval/:from/:to", TransactionController, :txs_for_interval

    # Not need for the frontend
    get "/transactions/rate/:from/:to", TransactionController, :tx_rate

    get "/generations/:from/:to", GenerationController, :generations_by_range

    get "/compilers", UtilController, :get_available_compilers
    get "/height/at/:milliseconds", UtilController, :height_at_epoch
    get "/reward/height/:height", UtilController, :reward_at_height
    get "/size/current", UtilController, :current_size
    get "/size/height/:height", UtilController, :size
    get "/status", UtilController, :status
    get "/count/current", UtilController, :current_count

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
end
