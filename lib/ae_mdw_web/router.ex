defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  @paginables ["txs", "names"]
  @scopes ["gen", "txi"]

  pipeline :api do
    plug AeMdwWeb.DataStreamPlug, paginables: @paginables, scopes: @scopes
    plug :accepts, ["json"]
  end

  scope "/", AeMdwWeb do
    pipe_through :api

    get "/tx/:hash", TxController, :tx
    get "/txi/:index", TxController, :txi

    get "/txs/count", TxController, :count
    get "/txs/count/:id", TxController, :count_id

    get "/txs/:direction", TxController, :txs_direction
    get "/txs/:scope_type/:range", TxController, :txs_range


    get "/names/:direction", NameController, :all_direction
    get "/names/:scope_type/:range", NameController, :all_range



    get "/status", UtilController, :status

    #### variants of these can be implemented when requested:

    # get "/names", :all_names
    # get "/names/:name", :search_names
    # get "/names/active", :active_names
    # get "/names/auctions/active", :active_name_auctions
    # get "/names/auctions/active/count", :active_name_auctions_count
    # get "/names/auctions/bids/account/:account", :bids_for_account
    # get "/names/auctions/bids/:name", :bids_for_name
    # get "/names/reverse/:account", :reverse_names
    # get "/names/auctions/:name/info", :info_for_auction
    # get "/names/hash/:hash", :name_for_hash

    # get "/generations/:from/:to", :interval
    # get "/compilers", :get_available_compilers
    # get "/height/at/:milliseconds", :height_at_epoch
    # get "/reward/height/:height", :reward_at_height
    # get "/size/current", :current_size
    # get "/size/height/:height", :size
    # get "/count/current", :current_count
    # get "/count/height/:height", :count
    # get "/micro-blocks/hash/:hash/transactions/count", :transaction_count_in_micro_block
    # get "/contracts/transactions/creation/address/:address, :creation_tx_for_contract_address
    # get "/new/generations/:from/:to, :generations_by_range2
    # get "/transactions/:hash", :tx_by_hash
    # get "/generations/current", :current_generations
    # get "/generations/height/:height", :generation_by_height
    # get "/key-blocks/current/height", :current_key_block_height
    # get "/key-blocks/hash/:hash", :key_block_by_hash
    # get "/key-blocks/height/:height", :key_block_by_height
    # get "/micro-blocks/hash/:hash/header", :micro_block_header_by_hash
    # get "/micro-blocks/hash/:hash/transactions", :micro_block_transactions_by_hash
    # get "/micro-blocks/hash/:hash/transactions/count", :micro_block_transactions_count_by_hash
    # get "/accounts/:account", :get_account_details
  end

  scope "/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :ae_mdw,
      swagger_file: "swagger.json",
      disable_validator: true
  end

  def swagger_info do
    %{
      basePath: "/",
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
