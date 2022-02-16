defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  @shared_routes [
    {"/block/:hash", AeMdwWeb.BlockController, :block},
    {"/blocki/:kbi", AeMdwWeb.BlockController, :blocki},
    {"/blocki/:kbi/:mbi", AeMdwWeb.BlockController, :blocki},
    {"/tx/:hash", AeMdwWeb.TxController, :tx},
    {"/txi/:index", AeMdwWeb.TxController, :txi},
    {"/txs/count", AeMdwWeb.TxController, :count},
    {"/txs/count/:id", AeMdwWeb.TxController, :count_id},
    {"/txs/:direction", AeMdwWeb.TxController, :txs},
    {"/txs/:scope_type/:range", AeMdwWeb.TxController, :txs},
    {"/name/auction/:id", AeMdwWeb.NameController, :auction},
    {"/name/pointers/:id", AeMdwWeb.NameController, :pointers},
    {"/name/pointees/:id", AeMdwWeb.NameController, :pointees},
    {"/name/:id", AeMdwWeb.NameController, :name},
    {"/names/search/:prefix", AeMdwWeb.NameController, :search},
    {"/names/owned_by/:id", AeMdwWeb.NameController, :owned_by},
    {"/names/auctions", AeMdwWeb.NameController, :auctions},
    {"/names/auctions/:scope_type/:range", AeMdwWeb.NameController, :auctions},
    {"/names/inactive", AeMdwWeb.NameController, :inactive_names},
    {"/names/inactive/:scope_type/:range", AeMdwWeb.NameController, :inactive_names},
    {"/names/active", AeMdwWeb.NameController, :active_names},
    {"/names/active/:scope_type/:range", AeMdwWeb.NameController, :active_names},
    {"/names", AeMdwWeb.NameController, :names},
    {"/names/:scope_type/:range", AeMdwWeb.NameController, :names},
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
    {"/aex9/transfers/from/:sender", AeMdwWeb.Aex9Controller, :transfers_from},
    {"/aex9/transfers/to/:recipient", AeMdwWeb.Aex9Controller, :transfers_to},
    {"/aex9/transfers/from-to/:sender/:recipient", AeMdwWeb.Aex9Controller, :transfers_from_to},
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
      Enum.each(@shared_routes, fn {path, controller, fun} ->
        get(path, controller, fun, alias: false)
      end)

      # v2-only routes
      get "/blocks/gen/:range", BlockController, :blocks_v2
      get "/blocks/:direction", BlockController, :blocks_v2
    end

    Enum.each(@shared_routes, fn {path, controller, fun} ->
      get(path, controller, fun, alias: false)
    end)

    # v1-only routes
    get "/blocks/gen/:range", BlockController, :blocks
    get "/blocks/:range_or_dir", BlockController, :blocks

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
