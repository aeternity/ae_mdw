defmodule AeMdwWeb.Router do
  use AeMdwWeb, :router
  use Plug.ErrorHandler

  alias AeMdwWeb.Plugs.AsyncStatePlug
  alias AeMdwWeb.Plugs.StatePlug
  alias AeMdwWeb.Plugs.DeprecationLoggerPlug
  alias AeMdwWeb.Plugs.JSONFormatterPlug
  alias AeMdwWeb.Plugs.RequestSpan
  alias AeMdwWeb.Util

  pipeline :api do
    plug :accepts, ["json"]
    plug StatePlug
    plug AsyncStatePlug
    plug JSONFormatterPlug
    plug Plug.RequestId
    plug RequestSpan
    plug DeprecationLoggerPlug
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

    scope "/v3" do
      get "/key-blocks", BlockController, :key_blocks
      get "/key-blocks/:hash_or_kbi", BlockController, :key_block
      get "/key-blocks/:hash_or_kbi/micro-blocks", BlockController, :key_block_micro_blocks
      get "/micro-blocks/:hash", BlockController, :micro_block
      get "/micro-blocks/:hash/transactions", TxController, :micro_block_txs

      get "/transactions/count", TxController, :count
      get "/transactions/pending", TxController, :pending_txs
      get "/transactions/pending/count", TxController, :pending_txs_count
      get "/transactions", TxController, :txs
      get "/transactions/:hash", TxController, :tx

      get "/oracles", OracleController, :oracles
      get "/oracles/:id", OracleController, :oracle
      get "/oracles/:id/queries", OracleController, :oracle_queries
      get "/oracles/:id/responses", OracleController, :oracle_responses
      get "/oracles/:id/extends", OracleController, :oracle_extends

      get "/channels", ChannelController, :channels
      get "/channels/:id", ChannelController, :channel
      get "/channels/:id/updates", ChannelController, :channel_updates

      get "/contracts", ContractController, :contracts
      get "/contracts/logs", ContractController, :logs
      get "/contracts/calls", ContractController, :calls
      get "/contracts/:id", ContractController, :contract
      get "/contracts/:contract_id/logs", ContractController, :contract_logs
      get "/contracts/:contract_id/calls", ContractController, :contract_calls

      get "/accounts/:id/activities", ActivityController, :account_activities
      get "/accounts/:account_id/aex9/balances", AexnTokenController, :aex9_account_balances
      get "/accounts/:account_id/aex141/tokens", Aex141Controller, :owned_nfts
      get "/accounts/:account_id/names/pointees", NameController, :pointees
      get "/accounts/:account_id/names/claims", NameController, :account_claims
      get "/accounts/:account_id/dex/swaps", DexController, :account_swaps
      get "/accounts/:id/transactions/count", TxController, :count_id

      get "/stats/transactions", StatsController, :transactions_stats
      get "/stats/blocks", StatsController, :blocks_stats
      get "/stats/difficulty", StatsController, :difficulty_stats
      get "/stats/hashrate", StatsController, :hashrate_stats
      get "/stats/total-accounts", StatsController, :total_accounts_stats
      get "/stats/active-accounts", StatsController, :active_accounts_stats
      get "/stats/names", StatsController, :names_stats
      get "/stats/total", StatsController, :total_stats
      get "/stats/delta", StatsController, :delta_stats
      get "/stats/miners", StatsController, :miners_stats
      get "/stats/contracts", StatsController, :contracts_stats
      get "/stats/aex9-transfers", StatsController, :aex9_transfers_stats
      get "/stats", StatsController, :stats

      get "/names", NameController, :names
      get "/names/count", NameController, :names_count
      get "/names/auctions", NameController, :auctions
      get "/names/auctions/:id", NameController, :auction
      get "/names/auctions/:id/claims", NameController, :auction_claims
      get "/names/:id", NameController, :name
      get "/names/:id/claims", NameController, :name_claims
      get "/names/:id/updates", NameController, :name_updates
      get "/names/:id/transfers", NameController, :name_transfers
      get "/names/:id/history", NameController, :name_history

      get "/transfers", TransferController, :transfers
      get "/status", UtilController, :status

      get "/aex9", AexnTokenController, :aex9_contracts
      get "/aex9/count", AexnTokenController, :aex9_count
      get "/aex9/:contract_id", AexnTokenController, :aex9_contract
      get "/aex9/:contract_id/balances", AexnTokenController, :aex9_event_balances
      get "/aex9/:contract_id/balances/:account_id", AexnTokenController, :aex9_token_balance

      get "/aex9/:contract_id/balances/:account_id/history",
          AexnTokenController,
          :aex9_token_balance_history

      get "/aex9/:contract_id/transfers", AexnTransferController, :aex9_contract_transfers

      get "/aex141", AexnTokenController, :aex141_contracts
      get "/aex141/count", AexnTokenController, :aex141_count
      get "/aex141/transfers", AexnTransferController, :aex141_transfers
      get "/aex141/:contract_id", AexnTokenController, :aex141_contract
      get "/aex141/:contract_id/tokens/:token_id", Aex141Controller, :nft_owner_v2
      get "/aex141/:contract_id/tokens", Aex141Controller, :collection_owners
      get "/aex141/:contract_id/templates", Aex141Controller, :collection_templates
      get "/aex141/:contract_id/transfers", AexnTransferController, :aex141_transfers

      get "/aex141/:contract_id/templates/:template_id/tokens",
          Aex141Controller,
          :collection_template_tokens

      get "/dex/swaps", DexController, :swaps
      get "/dex/:contract_id/swaps", DexController, :contract_swaps
      get "/wealth", WealthController, :wealth

      get "/hyperchain/schedule", HyperchainController, :schedule
      get "/hyperchain/schedule/height/:height", HyperchainController, :schedule_at_height
      get "/hyperchain/epochs", HyperchainController, :epochs
      get "/hyperchain/epochs/top", HyperchainController, :epochs_top
      get "/hyperchain/validators", HyperchainController, :validators
      get "/hyperchain/validators/top", HyperchainController, :validators_top

      get "/hyperchain/validators/:validator_id/delegates",
          HyperchainController,
          :validator_delegates

      get "/hyperchain/validators/:validator_id/delegates/top",
          HyperchainController,
          :validator_delegates_top

      get "/hyperchain/validators/:validator_id", HyperchainController, :validator

      get "/api", UtilController, :static_file,
        assigns: %{filepath: "static/swagger/swagger_v3.json"}
    end

    scope "/v2" do
      # v2-only routes
      get "/blocks", BlockController, :blocks
      get "/blocks/:hash_or_kbi", BlockController, :block
      get "/blocks/:kbi/:mbi", BlockController, :blocki
      get "/key-blocks", BlockController, :key_blocks
      get "/key-blocks/:hash_or_kbi", BlockController, :key_block
      get "/key-blocks/:hash_or_kbi/micro-blocks", BlockController, :key_block_micro_blocks
      get "/micro-blocks/:hash", BlockController, :micro_block
      get "/micro-blocks/:hash/txs", TxController, :micro_block_txs_v2

      get "/txs", TxController, :txs_v2
      get "/txs/count", TxController, :count
      get "/txs/:hash_or_index", TxController, :tx_v2
      get "/txs/count/:id", TxController, :count_id

      get "/entities/:id", ActiveEntityController, :active_entities

      get "/names/auctions", NameController, :auctions_v2
      get "/names/:id/auction", NameController, :auction_v2
      get "/names/:id/pointers", NameController, :pointers
      get "/names/:id/pointees", NameController, :pointees_v2
      get "/names/search", NameController, :search
      get "/names", NameController, :names_v2
      get "/names/:id", NameController, :name_v2
      get "/names/:id/history", NameController, :name_history
      get "/names/:id/claims", NameController, :name_claims
      get "/names/:id/updates", NameController, :name_updates
      get "/names/:id/transfers", NameController, :name_transfers

      get "/aex9", AexnTokenController, :aex9_contracts
      get "/aex9/count", AexnTokenController, :aex9_count
      get "/aex9/:contract_id", AexnTokenController, :aex9_contract
      get "/aex9/:contract_id/balances", AexnTokenController, :aex9_event_balances
      get "/aex9/:contract_id/logs-count", AexnTokenController, :aex9_logs_count
      get "/aex9/:contract_id/balances/:account_id", AexnTokenController, :aex9_token_balance
      get "/aex9/account-balances/:account_id", AexnTokenController, :aex9_account_balances

      get "/aex9/transfers/from/:sender", AexnTransferController, :aex9_transfers_from
      get "/aex9/transfers/to/:recipient", AexnTransferController, :aex9_transfers_to

      get "/aex9/transfers/from-to/:sender/:recipient",
          AexnTransferController,
          :aex9_transfers_from_to

      get "/aex141", AexnTokenController, :aex141_contracts_v2
      get "/aex141/count", AexnTokenController, :aex141_count
      get "/aex141/:contract_id", AexnTokenController, :aex141_contract_v2
      get "/aex141/:contract_id/owner/:token_id", Aex141Controller, :nft_owner
      get "/aex141/:contract_id/metadata/:token_id", Aex141Controller, :nft_metadata
      get "/aex141/:contract_id/owners", Aex141Controller, :collection_owners
      get "/aex141/:contract_id/templates", Aex141Controller, :collection_templates

      get "/aex141/:contract_id/templates/:template_id/tokens",
          Aex141Controller,
          :collection_template_tokens

      get "/aex141/owned-nfts/:account_id", Aex141Controller, :owned_nfts
      get "/aex141/transfers/:contract_id", AexnTransferController, :aex141_transfers_v2
      get "/aex141/transfers/from/:sender", AexnTransferController, :aex141_transfers_from
      get "/aex141/transfers/to/:recipient", AexnTransferController, :aex141_transfers_to

      get "/aex141/transfers/from-to/:sender/:recipient",
          AexnTransferController,
          :aex141_transfers_from_to

      get "/aex9/:contract_id/balances/:account_id/history",
          AexnTokenController,
          :aex9_token_balance_history

      get "/transfers", TransferController, :transfers

      get "/oracles", OracleController, :oracles_v2
      get "/oracles/:id", OracleController, :oracle_v2
      get "/oracles/:id/queries", OracleController, :oracle_queries
      get "/oracles/:id/responses", OracleController, :oracle_responses

      get "/channels", ChannelController, :channels
      get "/channels/:id", ChannelController, :channel
      get "/channels/:id/updates", ChannelController, :channel_updates

      get "/contracts", ContractController, :contracts
      get "/contracts/logs", ContractController, :logs_v2
      get "/contracts/calls", ContractController, :calls_v2
      get "/contracts/:id", ContractController, :contract

      get "/accounts/:id/activities", ActivityController, :account_activities

      get "/totalstats", StatsController, :total_stats
      get "/deltastats", StatsController, :delta_stats
      get "/stats", StatsController, :stats
      get "/minerstats", StatsController, :miners_stats
      get "/wealth", WealthController, :wealth

      get "/api", UtilController, :static_file,
        assigns: %{filepath: "static/swagger/swagger_v2.json"}
    end

    # v1-only routes
    get "/blocks/:range_or_dir", BlockController, :blocks_v1

    get "/tx/:hash_or_index", TxController, :tx_v2
    get "/txs/:direction", TxController, :txs_v2
    get "/txs/:scope_type/:range", TxController, :txs_v2

    get "/aex9/transfers/from/:sender", AexnTransferController, :transfers_from_v1
    get "/aex9/transfers/to/:recipient", AexnTransferController, :transfers_to_v1

    get "/contracts/calls/:scope_type/:range", ContractController, :calls

    get "/transfers/:scope_type/:range", TransferController, :transfers

    get "/aex9/by_name", Aex9Controller, :by_names

    get "/aex9/balance/hash/:blockhash/:contract_id/:account_id",
        Aex9Controller,
        :balance_for_hash

    get "/aex9/balances/account/:account_id", Aex9Controller, :balances
    get "/aex9/balances/:contract_id", Aex9Controller, :balances

    get "/status", UtilController, :status

    if Application.compile_env(:ae_mdw, :enable_livedashboard, false) do
      import Phoenix.LiveDashboard.Router

      scope "/" do
        pipe_through :browser
        live_dashboard "/dashboard", metrics: AeMdw.APM.Telemetry
      end
    end

    get "/api", UtilController, :static_file, assigns: %{filepath: "static/swagger/swagger.json"}
    get "/debug/rollback", UtilController, :rollback

    match :*, "/*path", UtilController, :no_route
  end

  @impl Plug.ErrorHandler
  def handle_errors(%{query_params: query_params} = conn, %{
        kind: :error,
        reason: %AeMdw.Error.Input{reason: reason, message: message} = input_error
      }) do
    :telemetry.execute([:ae_mdw, :error], %{status: 400}, %{
      request_path: conn.request_path,
      query_params: query_params,
      reason: inspect(input_error)
    })

    Util.send_error(conn, reason, message)
  end

  def handle_errors(%{status: 500, query_params: query_params} = conn, %{
        kind: :error,
        reason: reason
      }) do
    :telemetry.execute([:ae_mdw, :error], %{status: 500}, %{
      request_path: conn.request_path,
      query_params: query_params,
      reason: inspect(reason)
    })

    send_resp(conn, 500, "Internal Server Error")
  end

  def handle_errors(conn, _error) do
    conn
  end
end
