defmodule AeMdw.Application do
  @moduledoc """
  Before starting the supervision tree, the application runs:
  - a start phase of database migrations
  - a start phase of managing the ingestion/synchronization of chain data (with DynamicSupervisor)
  - initializes some deps apps
  - imports some Node calls

  Then it starts the supervision tree for the Async tasks, Websocket broadcasting and API endpoints.
  """
  alias AeMdw.Contract
  alias AeMdw.Db.HardforkPresets
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDb
  alias AeMdw.Db.Sync.ObjectKeys
  alias AeMdw.EtsCache
  alias AeMdw.Sync.Hyperchain
  alias AeMdw.Sync.Watcher
  alias AeMdwWeb.Websocket.BroadcasterCache
  alias AeMdw.Sync.MutationsCache
  alias AeMdw.Sync.Server, as: SyncServer
  alias AeMdw.Sync.SyncingQueue

  require Model
  require Logger

  use Application

  @impl Application
  def start(_type, _args) do
    hyperchain_checks()
    build_rev = Application.fetch_env!(:ae_mdw, :build_revision)
    :persistent_term.put({:ae_mdw, :build_revision}, build_rev)

    :lager.set_loglevel(:epoch_sync_lager_event, :lager_console_backend, :undefined, :error)

    init_public(:contract_cache)
    init(:app_ctrl_server)
    init(:aecore_services)
    init(:aesync)
    init(:tables)
    init(:formatters)

    persist = Application.get_env(:aecore, :persist, true)
    :ok = RocksDb.open(!persist)

    children = [
      AeMdwWeb.Supervisor,
      AeMdwWeb.Websocket.Supervisor,
      AeMdw.Sync.Supervisor,
      AeMdw.APM.Telemetry
    ]

    children =
      if Application.fetch_env!(:ae_mdw, :sync) do
        [AeMdw.Sync.AsyncTasks.Supervisor | children]
      else
        children
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  defp init(:aecore_services) do
    # need to be started after app_ctrl_server
    {:ok, _apps1} = Application.ensure_all_started(:aehttp)
    {:ok, _apps2} = Application.ensure_all_started(:aestratum)
    {:ok, _apps3} = Application.ensure_all_started(:aemon)
  end

  defp init(:app_ctrl_server) do
    :app_ctrl_server.start()
    :app_ctrl.set_mode(:normal)
  end

  defp init(:aesync), do: Application.ensure_all_started(:aesync)

  defp init(:tables) do
    BroadcasterCache.init()
    MutationsCache.init()

    _table = :ets.new(:sync_profiling, [:named_table, :set, :public])

    AeMdw.Sync.AsyncTasks.Stats.init()
    AeMdw.Sync.AsyncTasks.Store.init()

    AeMdw.Db.AsyncStore.init()
    AeMdw.Sync.Aex9BalancesCache.init()
  end

  defp init(:formatters) do
    with [custom_events_args: custom_args] <- Application.get_env(:ae_mdw, AeMdwWeb.LogsView, :ok) do
      :persistent_term.put({AeMdwWeb.LogsView, :custom_events_args}, true)

      Enum.each(custom_args, fn {event_name, index_map} ->
        :persistent_term.put({AeMdwWeb.LogsView, event_name}, index_map)

        event_hash = :aec_hash.blake2b_256_hash(event_name)
        :persistent_term.put({AeMdwWeb.LogsView, event_hash}, event_name)
      end)
    end
  end

  @spec init_public(:contract_cache) :: :ok
  def init_public(:contract_cache) do
    cache_exp = Application.fetch_env!(:ae_mdw, :contract_cache_expiration_minutes)
    EtsCache.new(Contract.table(), cache_exp)
    :ok
  end

  @impl Application
  def start_phase(:migrate_db, _start_type, []) do
    {:ok, _applied_count} = Mix.Tasks.MigrateDb.run(true)
    :ok
  end

  def start_phase(:hardforks_presets, _start_type, []) do
    HardforkPresets.import_account_presets()
    :ok
  end

  def start_phase(:load, _start_type, []) do
    ObjectKeys.load()
  end

  def start_phase(:start_sync, _start_type, []) do
    if Application.fetch_env!(:ae_mdw, :sync) do
      SyncingQueue.enqueue(fn ->
        SyncServer.start_sync()
        Watcher.start_sync()
      end)
    end

    :ok
  end

  @impl Application
  def stop(_state) do
    :ok = RocksDb.close()
  end

  # Tell Phoenix to update the endpoint configuration whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    AeMdwWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp hyperchain_checks() do
    if Hyperchain.hyperchain?() and not Hyperchain.connected_to_parent?() do
      Logger.error("Hyperchain is enabled but not connected to parent chain")
      raise "Hyperchain is enabled but not connected to parent chain"
    end
  end
end
