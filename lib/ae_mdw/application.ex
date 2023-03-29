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
  alias AeMdw.Db.Model
  alias AeMdw.EtsCache
  alias AeMdw.Extract
  alias AeMdw.NodeHelper
  alias AeMdw.Sync.Watcher
  alias AeMdw.Util
  alias AeMdwWeb.Websocket.Broadcaster

  require Model

  use Application

  @impl Application
  def start(_type, _args) do
    build_rev = Application.fetch_env!(:ae_mdw, :build_revision)
    :persistent_term.put({:ae_mdw, :build_revision}, build_rev)

    :lager.set_loglevel(:epoch_sync_lager_event, :lager_console_backend, :undefined, :error)
    :lager.set_loglevel(:lager_console_backend, :error)

    init(:meta)
    init_public(:contract_cache)
    init(:app_ctrl_server)
    init(:aecore_services)
    init(:aesync)
    init(:tables)

    :ok = AeMdw.Db.RocksDb.open()

    children = [
      AeMdw.APM.Telemetry,
      AeMdwWeb.Supervisor,
      AeMdwWeb.Websocket.Supervisor,
      AeMdw.Sync.Supervisor
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

  defp init(:meta) do
    {:ok, chain_state_code} = Extract.AbsCode.module(:aec_chain_state)
    [:header, :hash, :type] = NodeHelper.record_keys(chain_state_code, :node)

    {:ok, aetx_code} = Extract.AbsCode.module(:aetx)
    {:ok, aeser_code} = Extract.AbsCode.module(:aeser_api_encoder)

    type_mod_map = Extract.tx_mod_map(aetx_code)
    type_name_map = Extract.tx_name_map(aetx_code)
    id_prefix_type_map = Extract.id_prefix_type_map(aeser_code)
    id_type_map = Extract.id_type_map(aeser_code)
    type_mod_mapper = &Map.fetch!(type_mod_map, &1)

    {tx_field_types, tx_fields, tx_ids} =
      Enum.reduce(type_mod_map, {%{}, %{}, %{}}, fn {type, _},
                                                    {tx_field_types, tx_fields, tx_ids} ->
        {fields, ids} = Extract.tx_record_info(type, type_mod_mapper)

        tx_field_types =
          for {id_field, _} <- ids, reduce: tx_field_types do
            acc ->
              update_in(acc, [id_field], fn set -> MapSet.put(set || MapSet.new(), type) end)
          end

        {tx_field_types, put_in(tx_fields[type], fields), put_in(tx_ids[type], ids)}
      end)

    IO.inspect(tx_ids)

    inner_field_positions =
      tx_ids
      |> Map.values()
      |> Enum.flat_map(fn fields_pos_map ->
        Enum.map(fields_pos_map, fn
          {:ga_id, pos} -> {:ga_id, pos}
          {:payer_id, pos} -> {:payer_id, pos}
          {field, pos} -> {field, AeMdw.Fields.field_pos_mask(:ga_meta_tx, pos)}
        end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.into(%{}, fn {field, positions} ->
        {field, Enum.uniq(positions)}
      end)

    tx_ids_positions =
      Enum.into(tx_ids, %{}, fn {type, field_ids} ->
        {type, Map.values(field_ids)}
      end)

    id_field_type_map =
      Enum.reduce(tx_ids, %{}, fn {type, ids_map}, acc ->
        for {field, pos} <- ids_map,
            reduce: acc,
            do: (acc -> Map.put(acc, [field], Map.put(Map.get(acc, [field], %{}), type, pos)))
      end)

    id_fields = id_field_type_map |> Map.keys() |> Enum.map(Util.compose(&to_string/1, &hd/1))

    tx_types = Map.keys(type_mod_map)
    tx_group = &("#{&1}" |> String.split("_") |> hd |> String.to_atom())
    tx_group_map = Enum.group_by(tx_types, tx_group)

    tx_prefix = fn tx_type ->
      str = to_string(tx_type)
      # drop "_tx"
      String.slice(str, 0, String.length(str) - 3)
    end

    min_block_reward_height =
      :aec_block_genesis.height() + :aec_governance.beneficiary_reward_delay() + 1

    SmartGlobal.new(
      AeMdw.Node,
      %{
        tx_mod: type_mod_map,
        tx_name: type_name_map,
        tx_type: Util.inverse(type_name_map),
        tx_fields: tx_fields,
        tx_ids: tx_ids,
        tx_ids_positions: tx_ids_positions,
        inner_field_positions: inner_field_positions,
        id_prefix: id_prefix_type_map,
        id_field_type: id_field_type_map |> Enum.concat([{[:_], nil}]),
        id_fields: [{[], MapSet.new(id_fields)}],
        tx_field_types: tx_field_types,
        tx_types: [{[], MapSet.new(tx_types)}],
        tx_prefixes: [{[], MapSet.new(tx_types |> Enum.map(tx_prefix))}],
        id_prefixes: [{[], MapSet.new(Map.keys(id_prefix_type_map))}],
        tx_group: tx_group_map,
        tx_groups: [{[], MapSet.new(Map.keys(tx_group_map))}],
        id_type: id_type_map,
        type_id: Util.inverse(id_type_map),
        aex9_signatures: [{[], AeMdw.Node.aex9_signatures()}],
        aexn_event_hash_types: [{[], AeMdw.Node.aexn_event_hash_types()}],
        aexn_event_names: [{[], AeMdw.Node.aexn_event_names()}],
        aex141_signatures: [{[], AeMdw.Node.aex141_signatures()}],
        previous_aex141_signatures: [{[], AeMdw.Node.previous_aex141_signatures()}],
        height_proto: [{[], AeMdw.Node.height_proto()}],
        lima_height: [{[], AeMdw.Node.lima_height()}],
        min_block_reward_height: [{[], min_block_reward_height}],
        token_supply_delta:
          Enum.map(NodeHelper.token_supply_delta(), fn {h, xs} -> {[h], xs} end) ++ [{[:_], 0}]
      }
    )
  end

  defp init(:app_ctrl_server) do
    :app_ctrl_server.start()
    :app_ctrl.set_mode(:normal)
  end

  defp init(:aesync), do: Application.ensure_all_started(:aesync)

  defp init(:tables) do
    :tx_sync_cache = :ets.new(:tx_sync_cache, [:named_table, :ordered_set, :public])

    {ets_table, ets_expiration} = Broadcaster.ets_config()
    EtsCache.new(ets_table, ets_expiration)

    AeMdw.Sync.AsyncTasks.Stats.init()
    AeMdw.Sync.AsyncTasks.Store.init()

    AeMdw.Db.AsyncStore.init()
    AeMdw.Sync.Aex9BalancesCache.init()
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
    AeMdw.Db.HardforkPresets.import_account_presets()
    :ok
  end

  def start_phase(:start_sync, _start_type, []) do
    if Application.fetch_env!(:ae_mdw, :sync) do
      Watcher.start_sync()
    end

    :ok
  end

  @impl Application
  def stop(_state) do
    :ok = AeMdw.Db.RocksDb.close()
  end

  # Tell Phoenix to update the endpoint configuration whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    AeMdwWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
