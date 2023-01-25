defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router

  alias AeMdwWeb.Plugs.StatePlug

  @shared_routes [
    {"/txs/count", AeMdwWeb.TxController, :count},
    {"/txs/count/:id", AeMdwWeb.TxController, :count_id},
    {"/transfers", AeMdwWeb.TransferController, :transfers},
    {"/contracts/logs", AeMdwWeb.ContractController, :logs},
    {"/contracts/calls", AeMdwWeb.ContractController, :calls},
    {"/totalstats/", AeMdwWeb.StatsController, :total_stats},
    {"/status", AeMdwWeb.UtilController, :status},
    {"/aex141", AeMdwWeb.AexnTokenController, :aex141_contracts},
    {"/aex141/:contract_id", AeMdwWeb.AexnTokenController, :aex141_contract},
    {"/aex141/:contract_id/owner/:token_id", AeMdwWeb.Aex141Controller, :nft_owner},
    {"/aex141/:contract_id/owners", AeMdwWeb.Aex141Controller, :collection_owners},
    {"/aex141/:contract_id/templates", AeMdwWeb.Aex141Controller, :collection_templates},
    {"/aex141/:contract_id/templates/:template_id/tokens", AeMdwWeb.Aex141Controller,
     :collection_template_tokens},
    {"/aex141/owned-nfts/:account_id", AeMdwWeb.Aex141Controller, :owned_nfts}
  ]

  pipeline :api do
    plug :accepts, ["json"]
    plug StatePlug
    plug Plug.RequestId
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
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
      get "/key-blocks", BlockController, :key_blocks
      get "/key-blocks/:hash_or_kbi", BlockController, :key_block
      get "/key-blocks/:hash_or_kbi/micro-blocks", BlockController, :key_block_micro_blocks
      get "/micro-blocks/:hash", BlockController, :micro_block
      get "/micro-blocks/:hash/txs", TxController, :micro_block_txs

      get "/txs", TxController, :txs
      get "/txs/:hash_or_index", TxController, :tx

      get "/names/:id/auction", NameController, :auction
      get "/names/:id/pointers", NameController, :pointers
      get "/names/:id/pointees", NameController, :pointees
      get "/names/auctions", NameController, :auctions
      get "/names/search", NameController, :search
      get "/names", NameController, :names
      get "/names/:id", NameController, :name
      get "/names/:id/claims", NameController, :name_claims
      get "/names/:id/updates", NameController, :name_updates
      get "/names/:id/transfers", NameController, :name_transfers

      get "/aex9", AexnTokenController, :aex9_contracts
      get "/aex9/:contract_id", AexnTokenController, :aex9_contract
      get "/aex9/:contract_id/balances", AexnTokenController, :aex9_event_balances
      get "/aex9/:contract_id/balances/:account_id", AexnTokenController, :aex9_token_balance
      get "/aex9/account-balances/:account_id", AexnTokenController, :aex9_account_balances

      get "/aex9/transfers/from/:sender", AexnTransferController, :aex9_transfers_from
      get "/aex9/transfers/to/:recipient", AexnTransferController, :aex9_transfers_to

      get "/aex9/transfers/from-to/:sender/:recipient",
          AexnTransferController,
          :aex9_transfers_from_to

      get "/aex141/transfers/:contract_id", AexnTransferController, :aex141_transfers
      get "/aex141/transfers/from/:sender", AexnTransferController, :aex141_transfers_from
      get "/aex141/transfers/to/:recipient", AexnTransferController, :aex141_transfers_to

      get "/aex141/transfers/from-to/:sender/:recipient",
          AexnTransferController,
          :aex141_transfers_from_to

      get "/aex9/:contract_id/balances/:account_id/history",
          AexnTokenController,
          :aex9_token_balance_history

      get "/oracles/:id", OracleController, :oracle
      get "/oracles", OracleController, :oracles

      get "/channels", ChannelController, :channels
      get "/channels/:id", ChannelController, :channel

      get "/accounts/:id/activities", ActivityController, :account_activities

      get "/deltastats", StatsController, :delta_stats
      get "/stats", StatsController, :stats
      get "/minerstats", StatsController, :miners
    end

    Enum.each(@shared_routes, fn {path, controller, fun} ->
      get(path, controller, fun, alias: false)
    end)

    # v1-only routes
    get "/blocks/gen/:range", BlockController, :blocks_v1
    get "/blocks/:range_or_dir", BlockController, :blocks_v1
    get "/block/:hash_or_kbi", BlockController, :block_v1
    get "/blocki/:kbi", BlockController, :blocki
    get "/blocki/:kbi/:mbi", BlockController, :blocki

    get "/tx/:hash_or_index", TxController, :tx
    get "/txi/:index", TxController, :txi
    get "/txs/:direction", TxController, :txs
    get "/txs/:scope_type/:range", TxController, :txs

    get "/name/auction/:id", NameController, :auction
    get "/name/pointers/:id", NameController, :pointers
    get "/name/pointees/:id", NameController, :pointees
    get "/name/:id", NameController, :name
    get "/names/search/:prefix", NameController, :search_v1
    get "/names/auctions", NameController, :auctions
    get "/names/auctions/:scope_type/:range", NameController, :auctions
    get "/names/inactive", NameController, :inactive_names
    get "/names/inactive/:scope_type/:range", NameController, :inactive_names
    get "/names/active", NameController, :active_names
    get "/names/active/:scope_type/:range", NameController, :active_names
    get "/names/owned_by/:id", NameController, :owned_by
    get "/names", NameController, :names
    get "/names/:scope_type/:range", NameController, :names

    get "/aex9/transfers/from/:sender", AexnTransferController, :transfers_from_v1
    get "/aex9/transfers/to/:recipient", AexnTransferController, :transfers_to_v1

    get "/aex9/transfers/from-to/:sender/:recipient",
        AexnTransferController,
        :transfers_from_to_v1

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

    get "/stats", StatsController, :stats_v1
    get "/stats/:direction", StatsController, :stats
    get "/stats/:scope_type/:range", StatsController, :stats
    get "/totalstats/:direction", StatsController, :total_stats
    get "/totalstats/:scope_type/:range", StatsController, :total_stats

    if Application.get_env(:ae_mdw, :livedashboard_enabled?, false) do
      import Phoenix.LiveDashboard.Router

      scope "/" do
        pipe_through :browser
        live_dashboard "/dashboard", metrics: AeMdw.APM.Telemetry
      end
    end

    match :*, "/*path", UtilController, :no_route
  end
end
