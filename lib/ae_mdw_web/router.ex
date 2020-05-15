defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  @paginables ["txs", "names", "oracles", "channels", "contracts"]
  @scopes ["gen", "txi"]

  pipeline :api do
    plug CORSPlug, origin: "*"
    plug AeMdwWeb.DataStreamPlug, paginables: @paginables, scopes: @scopes
    plug :accepts, ["json"]
  end

  scope "/", AeMdwWeb do
    pipe_through :api

    # get "/channels/active", ChannelController, :active_channels
    # get "/channels/transactions/address/:address", ChannelController, :txs_for_channel_address

    # get "/oracles/list", OracleController, :all
    # # seems like there are not registered oracles in aeternal
    # get "/oracles/:oracle_id", OracleController, :requests_responses

    # get "/contracts/all", ContractController, :all
    # get "/contracts/transactions/address/:address", ContractController, :transactions
    # get "/contracts/calls/address/:address", ContractController, :calls
    # post "/contracts/verify", ContractController, :verify

    # get "/names", NameController, :all_names
    # get "/names/:name", NameController, :search_names
    # get "/names/active", NameController, :active_names
    # get "/names/auctions/active", NameController, :active_name_auctions
    # get "/names/auctions/active/count", NameController, :active_name_auctions_count
    # get "/names/auctions/bids/account/:account", NameController, :bids_for_account
    # get "/names/auctions/bids/:name", NameController, :bids_for_name
    # get "/names/reverse/:account", NameController, :reverse_names
    # get "/names/auctions/:name/info", NameController, :info_for_auction
    # get "/names/hash/:hash", NameController, :name_for_hash
    # get "/transactions/account/:address/count", TransactionController, :count

    get "/tx/:hash", TxController, :tx
    get "/txi/:index", TxController, :txi

    get "/txs/:scope_type/:range", TxController, :txs
    get "/txs/:direction", TxController, :txs
    get "/txs/:scope_type/:range/or", TxController, :txs_or
    get "/txs/:direction/or", TxController, :txs_or
    get "/txs/:scope_type/:range/and", TxController, :txs_and
    get "/txs/:direction/and", TxController, :txs_and

    # get "/generations/:from/:to", GenerationController, :interval

    # get "/compilers", UtilController, :get_available_compilers
    # get "/height/at/:milliseconds", UtilController, :height_at_epoch
    # get "/reward/height/:height", UtilController, :reward_at_height
    # get "/size/current", UtilController, :current_size
    # get "/size/height/:height", UtilController, :size
    # get "/status", UtilController, :status
    # get "/count/current", UtilController, :current_count

    # get "/count/height/:height", :count
    # get "/micro-blocks/hash/:hash/transactions/count", :transaction_count_in_micro_block
    # get "/contracts/transactions/creation/address/:address, :creation_tx_for_contract_address
    # get "/new/generations/:from/:to, :generations_by_range2
  end

  # scope "/v2", AeMdwWeb do
  #   pipe_through :api

  #   get "/transactions/:hash", AeNodeController, :tx_by_hash
  #   get "/generations/current", AeNodeController, :current_generations
  #   get "/generations/height/:height", AeNodeController, :generation_by_height
  #   get "/key-blocks/current/height", AeNodeController, :current_key_block_height
  #   get "/key-blocks/hash/:hash", AeNodeController, :key_block_by_hash
  #   get "/key-blocks/height/:height", AeNodeController, :key_block_by_height
  #   get "/micro-blocks/hash/:hash/header", AeNodeController, :micro_block_header_by_hash

  #   get "/micro-blocks/hash/:hash/transactions",
  #       AeNodeController,
  #       :micro_block_transactions_by_hash

  #   get "/micro-blocks/hash/:hash/transactions/count",
  #       AeNodeController,
  #       :micro_block_transactions_count_by_hash

  #   get "/accounts/:account", AeNodeController, :get_account_details
  # end
end
