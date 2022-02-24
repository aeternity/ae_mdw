defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  @shared_routes [
    {"/tx/:hash", AeMdwWeb.TxController, :tx},
    {"/txi/:index", AeMdwWeb.TxController, :txi},
    {"/txs/count", AeMdwWeb.TxController, :count},
    {"/txs/count/:id", AeMdwWeb.TxController, :count_id},
    {"/txs/:direction", AeMdwWeb.TxController, :txs},
    {"/txs/:scope_type/:range", AeMdwWeb.TxController, :txs},
    {"/oracle/:id", AeMdwWeb.OracleController, :oracle},
    {"/oracles/inactive", AeMdwWeb.OracleController, :inactive_oracles},
    {"/oracles/active", AeMdwWeb.OracleController, :active_oracles},
    {"/oracles", AeMdwWeb.OracleController, :oracles},
    {"/oracles/inactive/gen/:range", AeMdwWeb.OracleController, :inactive_oracles},
    {"/oracles/active/gen/:range", AeMdwWeb.OracleController, :active_oracles},
    {"/oracles/gen/:range", AeMdwWeb.OracleController, :oracles},
    {"/aex9/by_contract/:id", AeMdwWeb.Aex9Controller, :by_contract},
    {"/aex9/by_name", AeMdwWeb.Aex9Controller, :by_names},
    {"/aex9/by_symbol", AeMdwWeb.Aex9Controller, :by_symbols},
    {"/aex9/balance/gen/:range/:contract_id/:account_id", AeMdwWeb.Aex9Controller,
     :balance_range},
    {"/aex9/balance/hash/:blockhash/:contract_id/:account_id", AeMdwWeb.Aex9Controller,
     :balance_for_hash},
    {"/aex9/balance/:contract_id/:account_id", AeMdwWeb.Aex9Controller, :balance},
    {"/aex9/balances/gen/:height/account/:account_id", AeMdwWeb.Aex9Controller, :balances},
    {"/aex9/balances/hash/:blockhash/account/:account_id", AeMdwWeb.Aex9Controller, :balances},
    {"/aex9/balances/account/:account_id", AeMdwWeb.Aex9Controller, :balances},
    {"/aex9/balances/gen/:range/:contract_id", AeMdwWeb.Aex9Controller, :balances_range},
    {"/aex9/balances/hash/:blockhash/:contract_id", AeMdwWeb.Aex9Controller, :balances_for_hash},
    {"/aex9/balances/:contract_id", AeMdwWeb.Aex9Controller, :balances},
    {"/contracts/logs", AeMdwWeb.ContractController, :logs},
    {"/contracts/logs/:direction", AeMdwWeb.ContractController, :logs},
    {"/contracts/logs/:scope_type/:range", AeMdwWeb.ContractController, :logs},
    {"/contracts/calls", AeMdwWeb.ContractController, :calls},
    {"/contracts/calls/:direction", AeMdwWeb.ContractController, :calls},
    {"/contracts/calls/:scope_type/:range", AeMdwWeb.ContractController, :calls},
    {"/transfers/:scope_type/:range", AeMdwWeb.TransferController, :transfers},
    {"/transfers/:direction", AeMdwWeb.TransferController, :transfers},
    {"/transfers", AeMdwWeb.TransferController, :transfers},
    {"/stats/", AeMdwWeb.StatsController, :stats},
    {"/stats/:direction", AeMdwWeb.StatsController, :stats},
    {"/stats/:scope_type/:range", AeMdwWeb.StatsController, :stats},
    {"/totalstats/", AeMdwWeb.StatsController, :sum_stats},
    {"/totalstats/:direction", AeMdwWeb.StatsController, :sum_stats},
    {"/totalstats/:scope_type/:range", AeMdwWeb.StatsController, :sum_stats},
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
      # v2-only routes
      get "/blocks", BlockController, :blocks
      get "/blocks/:hash_or_kbi", BlockController, :block
      get "/blocks/:kbi/:mbi", BlockController, :blocki

      get "/names/:id/auctions", NameController, :auction
      get "/names/:id/pointers", NameController, :pointers
      get "/names/:id/pointees", NameController, :pointees
      get "/names/auctions", NameController, :auctions
      get "/names/search", NameController, :search
      get "/names", NameController, :names
      get "/names/:id", NameController, :name

      get "/aex9/transfers/from/:sender", Aex9Controller, :transfers_from
      get "/aex9/transfers/to/:recipient", Aex9Controller, :transfers_to
      get "/aex9/transfers/from-to/:sender/:recipient", Aex9Controller, :transfers_from_to
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
