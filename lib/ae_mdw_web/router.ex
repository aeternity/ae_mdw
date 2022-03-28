defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  @shared_routes [
    {"/txs/count", AeMdwWeb.TxController, :count},
    {"/txs/count/:id", AeMdwWeb.TxController, :count_id},
    {"/transfers", AeMdwWeb.TransferController, :transfers},
    {"/contracts/logs", AeMdwWeb.ContractController, :logs},
    {"/contracts/calls", AeMdwWeb.ContractController, :calls},
    {"/totalstats/", AeMdwWeb.StatsController, :total_stats},
    {"/status", AeMdwWeb.UtilController, :status}
  ]

  pipeline :api do
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

  scope "/", AeMdwWeb do
    pipe_through :api

    scope "/v2" do
      Enum.each(@shared_routes, fn {path, controller, fun} ->
        get(path, controller, fun, alias: false)
      end)

      # v2-only routes
      get "/blocks", BlockController, :blocks
      get "/blocks/:hash_or_kbi", BlockController, :block
      get "/blocks/:kbi/:mbi", BlockController, :blocki

      get "/txs", TxController, :txs
      get "/txs/:hash_or_index", TxController, :tx

      get "/names/:id/auctions", NameController, :auction
      get "/names/:id/pointers", NameController, :pointers
      get "/names/:id/pointees", NameController, :pointees
      get "/names/auctions", NameController, :auctions
      get "/names/search", NameController, :search
      get "/names", NameController, :names
      get "/names/:id", NameController, :name

      get "/aex9", Aex9TokenController, :aex9_tokens
      get "/aex9/:contract_id", Aex9TokenController, :aex9_token
      get "/aex9/:contract_id/balances", Aex9TokenController, :aex9_token_balances
      get "/aex9/:contract_id/balances/:account_id", Aex9TokenController, :aex9_token_balance
      get "/aex9/account-balances/:account_id", Aex9TokenController, :aex9_account_balances
      get "/aex9/transfers/from/:sender", Aex9Controller, :transfers_from
      get "/aex9/transfers/to/:recipient", Aex9Controller, :transfers_to
      get "/aex9/transfers/from-to/:sender/:recipient", Aex9Controller, :transfers_from_to

      get "/aex9/:contract_id/balances/:account_id/history",
          Aex9TokenController,
          :aex9_token_balance_history

      get "/oracles/:id", OracleController, :oracle
      get "/oracles", OracleController, :oracles

      get "/deltastats", StatsController, :delta_stats
    end

    Enum.each(@shared_routes, fn {path, controller, fun} ->
      get(path, controller, fun, alias: false)
    end)

    # v1-only routes
    get "/blocks/gen/:range", BlockController, :blocks_v1
    get "/blocks/:range_or_dir", BlockController, :blocks_v1
    get "/block/:hash_or_kbi", BlockController, :block
    get "/blocki/:kbi", BlockController, :blocki
    get "/blocki/:kbi/:mbi", BlockController, :blocki

    get "/tx/:hash_or_index", TxController, :tx
    get "/txi/:index", TxController, :txi
    get "/txs/:direction", TxController, :txs
    get "/txs/:scope_type/:range", TxController, :txs

    get "/name/auction/:id", NameController, :auction
    get "/name/pointers/:id", NameController, :pointers
    get "/name/pointees/:id", NameController, :pointees
    get "/name/owned_by/:id", NameController, :owned_by
    get "/name/:id", NameController, :name
    get "/names/search/:prefix", NameController, :search_v1
    get "/names/auctions", NameController, :auctions
    get "/names/auctions/:scope_type/:range", NameController, :auctions
    get "/names/inactive", NameController, :inactive_names
    get "/names/inactive/:scope_type/:range", NameController, :inactive_names
    get "/names/active", NameController, :active_names
    get "/names/active/:scope_type/:range", NameController, :active_names
    get "/names", NameController, :names
    get "/names/:scope_type/:range", NameController, :names

    get "/aex9/transfers/from/:sender", Aex9Controller, :transfers_from_v1
    get "/aex9/transfers/to/:recipient", Aex9Controller, :transfers_to_v1
    get "/aex9/transfers/from-to/:sender/:recipient", Aex9Controller, :transfers_from_to_v1

    get "/contracts/logs/:direction", ContractController, :logs
    get "/contracts/logs/:scope_type/:range", ContractController, :logs
    get "/contracts/calls/:direction", ContractController, :calls
    get "/contracts/calls/:scope_type/:range", ContractController, :calls

    get "/oracle/:id", OracleController, :oracle
    get "/oracles/inactive", OracleController, :inactive_oracles
    get "/oracles/active", OracleController, :active_oracles
    get "/oracles", OracleController, :oracles
    get "/oracles/inactive/gen/:range", OracleController, :inactive_oracles
    get "/oracles/active/gen/:range", OracleController, :active_oracles
    get "/oracles/gen/:range", OracleController, :oracles

    get "/transfers/:scope_type/:range", TransferController, :transfers
    get "/transfers/:direction", TransferController, :transfers

    get "/aex9/by_contract/:id", Aex9Controller, :by_contract
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

    get "/stats", StatsController, :stats
    get "/stats/:direction", StatsController, :stats
    get "/stats/:scope_type/:range", StatsController, :stats
    get "/totalstats/:direction", StatsController, :total_stats
    get "/totalstats/:scope_type/:range", StatsController, :total_stats

    match :*, "/*path", UtilController, :no_route
  end

  @spec swagger_info() :: term()
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
