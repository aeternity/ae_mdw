defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  alias AeMdwWeb.DataStreamPlug

  @paginables [
    {["txs"], nil},
    {["blocks"], &AeMdwWeb.BlockController.stream_plug_hook/1},
    {["names", "auctions"], &AeMdwWeb.NameController.stream_plug_hook/1},
    {["names", "inactive"], &AeMdwWeb.NameController.stream_plug_hook/1},
    {["names", "active"], &AeMdwWeb.NameController.stream_plug_hook/1},
    {["names"], &AeMdwWeb.NameController.stream_plug_hook/1},
    {["oracles"], &AeMdwWeb.OracleController.stream_plug_hook/1},
    {["contracts", "logs"], &AeMdwWeb.ContractController.stream_plug_hook/1}
  ]

  @scopes ["gen", "txi"]

  pipeline :api do
    plug DataStreamPlug, paginables: @paginables, scopes: @scopes
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :ae_mdw,
      swagger_file: "swagger.json",
      disable_validator: true
  end

  scope "/frontend", AeMdwWeb do
    pipe_through :browser

    match :*, "/*path", WebPageController, :index
  end

  scope "/", AeMdwWeb do
    pipe_through :api

    get "/block/:hash", BlockController, :block
    get "/blocki/:kbi", BlockController, :blocki
    get "/blocki/:kbi/:mbi", BlockController, :blocki

    # for continuation link only
    get "/blocks/gen/:range", BlockController, :blocks
    # by default no scope_type needed
    get "/blocks/:range_or_dir", BlockController, :blocks

    get "/tx/:hash", TxController, :tx
    get "/txi/:index", TxController, :txi

    get "/txs/count", TxController, :count
    get "/txs/count/:id", TxController, :count_id
    get "/txs/:direction", TxController, :txs
    get "/txs/:scope_type/:range", TxController, :txs

    get "/name/auction/:id", NameController, :auction
    get "/name/pointers/:id", NameController, :pointers
    get "/name/pointees/:id", NameController, :pointees
    get "/name/:id", NameController, :name

    get "/names/owned_by/:id", NameController, :owned_by

    get "/names/auctions", NameController, :auctions
    get "/names/auctions/:scope_type/:range", NameController, :auctions

    get "/names/inactive", NameController, :inactive_names
    get "/names/inactive/:scope_type/:range", NameController, :inactive_names

    get "/names/active", NameController, :active_names
    get "/names/active/:scope_type/:range", NameController, :active_names

    get "/names", NameController, :names
    get "/names/:scope_type/:range", NameController, :names

    get "/oracle/:id", OracleController, :oracle

    get "/oracles/inactive", OracleController, :inactive_oracles
    get "/oracles/inactive/gen/:range", OracleController, :inactive_oracles

    get "/oracles/active", OracleController, :active_oracles
    get "/oracles/active/gen/:range", OracleController, :active_oracles

    get "/oracles", OracleController, :oracles
    get "/oracles/gen/:range", OracleController, :oracles

    get "/aex9/by_name", Aex9Controller, :by_names
    get "/aex9/by_symbol", Aex9Controller, :by_symbols

    get "/aex9/balance/gen/:range/:contract_id/:account_id", Aex9Controller, :balance_range

    get "/aex9/balance/hash/:blockhash/:contract_id/:account_id",
        Aex9Controller,
        :balance_for_hash

    get "/aex9/balance/:contract_id/:account_id", Aex9Controller, :balance

    get "/aex9/balances/gen/:height/account/:account_id", Aex9Controller, :balances
    get "/aex9/balances/hash/:blockhash/account/:account_id", Aex9Controller, :balances
    get "/aex9/balances/account/:account_id", Aex9Controller, :balances

    get "/aex9/balances/gen/:range/:contract_id", Aex9Controller, :balances_range
    get "/aex9/balances/hash/:blockhash/:contract_id", Aex9Controller, :balances_for_hash
    get "/aex9/balances/:contract_id", Aex9Controller, :balances

    get "/aex9/transfers/from/:sender", Aex9Controller, :transfers_from
    get "/aex9/transfers/to/:recipient", Aex9Controller, :transfers_to
    get "/aex9/transfers/from-to/:sender/:recipient", Aex9Controller, :transfers_from_to

    get "/contracts/logs", ContractController, :logs
    get "/contracts/logs/:direction", ContractController, :logs
    get "/contracts/logs/:scope_type/:range", ContractController, :logs

    get "/status", UtilController, :status

    match :*, "/*path", UtilController, :no_route
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
