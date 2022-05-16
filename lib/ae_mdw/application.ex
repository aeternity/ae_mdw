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
  alias AeMdw.Sync.Server
  alias AeMdw.EtsCache
  alias AeMdw.Extract
  alias AeMdw.NodeHelper
  alias AeMdw.Util

  require Model

  use Application

  @impl Application
  def start(_type, _args) do
    build_rev = Application.fetch_env!(:ae_mdw, :build_revision)
    :persistent_term.put({:ae_mdw, :build_revision}, build_rev)

    :lager.set_loglevel(:epoch_sync_lager_event, :lager_console_backend, :undefined, :error)
    :lager.set_loglevel(:lager_console_backend, :error)

    init(:node_records)
    init(:meta)
    init_public(:contract_cache)
    # init(:aesophia)
    init(:app_ctrl_server)
    init(:aecore_services)
    init(:aesync)
    init(:tables)

    :ok = AeMdw.Db.RocksDb.open()

    children = [
      AeMdw.Sync.Watcher,
      AeMdwWeb.Supervisor,
      AeMdwWeb.Websocket.Supervisor,
      Server
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
    Application.ensure_all_started(:aehttp)
    Application.ensure_all_started(:aestratum)
    Application.ensure_all_started(:aemon)
  end

  # def init(:aesophia) do
  #   Path.join(Application.app_dir(:aesophia), "ebin/*.beam")
  #   |> Path.wildcard
  #   |> Enum.map(&:code.load_abs(to_charlist(Path.rootname(&1))))
  # end

  defp init(:node_records) do
    {:ok, aeo_oracles_code} = Extract.AbsCode.module(:aeo_oracles)
    {:ok, aeo_query_code} = Extract.AbsCode.module(:aeo_query)

    oracle_fields = NodeHelper.record_keys(aeo_oracles_code, :oracle)
    query_fields = NodeHelper.record_keys(aeo_query_code, :query)

    SmartRecord.new(AeMdw.Node, :oracle, Enum.zip(oracle_fields, Stream.cycle([nil])))
    SmartRecord.new(AeMdw.Node, :oracle_query, Enum.zip(query_fields, Stream.cycle([nil])))
    :ok
  end

  defp init(:meta) do
    {:ok, chain_state_code} = Extract.AbsCode.module(:aec_chain_state)
    [:header, :hash, :type] = NodeHelper.record_keys(chain_state_code, :node)

    {:ok, aetx_code} = Extract.AbsCode.module(:aetx)
    {:ok, aeser_code} = Extract.AbsCode.module(:aeser_api_encoder)
    {:ok, headers_code} = Extract.AbsCode.module(:aec_headers)
    {:ok, aens_state_tree_code} = Extract.AbsCode.module(:aens_state_tree)
    {:ok, aeo_state_tree_code} = Extract.AbsCode.module(:aeo_state_tree)

    network_id = :aec_governance.get_network_id()

    hard_fork_heights =
      network_id
      |> :aec_hard_forks.protocols_from_network_id()
      |> Enum.sort_by(&elem(&1, 0))

    lima_vsn = :aec_hard_forks.protocol_vsn(:lima)

    lima_height =
      Enum.find_value(hard_fork_heights, fn
        {^lima_vsn, h} -> h
        _non_lima_val -> nil
      end)

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

    field_pos_map = fn code, rec ->
      code
      |> NodeHelper.record_keys(rec)
      |> Stream.zip(Stream.iterate(1, &(&1 + 1)))
      |> Enum.into(%{})
    end

    aex9_sigs =
      Contract.aex9_signatures()
      |> Enum.map(fn {k, v} -> {Contract.function_hash(k), v} end)
      |> Enum.into(%{})

    aex141_sigs =
      Contract.aex141_signatures()
      |> Enum.map(fn {k, v} -> {Contract.function_hash(k), v} end)
      |> Enum.into(%{})

    max_int = Util.max_256bit_int()
    max_blob = :binary.list_to_bin(:lists.duplicate(1024, <<max_int::256>>))

    height_proto = :aec_hard_forks.protocols() |> Enum.into([]) |> Enum.sort(&>=/2)

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
        hdr_fields: %{
          key: NodeHelper.record_keys(headers_code, :key_header),
          micro: NodeHelper.record_keys(headers_code, :mic_header)
        },
        aens_tree_pos: field_pos_map.(aens_state_tree_code, :ns_tree),
        aeo_tree_pos: field_pos_map.(aeo_state_tree_code, :oracle_tree),
        lima_vsn: [{[], lima_vsn}],
        lima_height: [{[], lima_height}],
        aex9_signatures: [{[], aex9_sigs}],
        aex9_transfer_event_hash: [{[], :aec_hash.blake2b_256_hash("Transfer")}],
        aex141_signatures: [{[], aex141_sigs}],
        max_blob: [{[], max_blob}],
        height_proto: [{[], height_proto}],
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
    :ets.new(:tx_sync_cache, [:named_table, :ordered_set, :public])
    :ets.new(:name_sync_cache, [:named_table, :ordered_set, :public])
    :ets.new(:oracle_sync_cache, [:named_table, :ordered_set, :public])
    :ets.new(:ct_create_sync_cache, [:named_table, :set, :public])
    :ets.new(:aex9_sync_cache, [:named_table, :set, :public])
    :ets.new(:stat_sync_cache, [:named_table, :ordered_set, :public])

    AeMdw.Sync.AsyncTasks.Stats.init()
    AeMdw.Sync.AsyncTasks.Store.init()

    AeMdw.Db.RocksDbCF.init_tables()
  end

  @spec init_public(atom()) :: :ok
  def init_public(:contract_cache) do
    cache_exp = Application.fetch_env!(:ae_mdw, :contract_cache_expiration_minutes)
    EtsCache.new(Contract.table(), cache_exp)
    :ok
  end

  @impl Application
  def start_phase(:migrate_db, _start_type, []) do
    Mix.Tasks.MigrateDb.run(true)
    :ok
  end

  def start_phase(:start_sync, _start_type, []) do
    if Application.fetch_env!(:ae_mdw, :sync) do
      Server.start_sync()
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
