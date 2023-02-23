defmodule AeMdw.Db.Status do
  @moduledoc """
  Database sync status from Mdw and local Node.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util
  alias AeMdw.Sync.AsyncTasks.Stats
  alias AeMdw.Sync.Server

  require Model

  @type gens_per_min() :: number()

  @gens_per_min_weight 0.1
  @gens_per_min_key :gens_per_min

  @spec node_and_mdw_status(State.t()) :: map()
  def node_and_mdw_status(state) do
    node_status = node_status()
    Map.merge(node_status, mdw_status(state, node_status.node_height))
  end

  @spec set_gens_per_min(gens_per_min()) :: :ok
  def set_gens_per_min(gens_per_min) do
    new_gens_per_min = calculate_gens_per_min(get_gens_per_min(), gens_per_min)

    :persistent_term.put(@gens_per_min_key, new_gens_per_min)
  end

  defp get_gens_per_min do
    case :persistent_term.get(@gens_per_min_key, :none) do
      :none -> 0
      gens_per_min -> gens_per_min
    end
  end

  defp node_status do
    {node_syncing?, node_progress} =
      with {node_syncing?, node_progress, _height} <- :aec_sync.sync_progress() do
        {node_syncing?, node_progress}
      end

    {:ok, top_kb} = :aec_chain.top_key_block()
    node_height = :aec_blocks.height(top_kb)

    %{
      node_version: :aeu_info.get_version(),
      node_revision: :aeu_info.get_revision(),
      node_height: node_height,
      node_syncing: node_syncing?,
      node_progress: node_progress
    }
  end

  defp mdw_status(state, node_height) do
    {mdw_tx_index, mdw_height} = safe_mdw_tx_index_and_height(state)
    mdw_syncing? = Server.syncing?()
    {:ok, version} = :application.get_key(:ae_mdw, :vsn)
    async_tasks_counters = Stats.counters()
    gens_per_minute = get_gens_per_min()

    %{
      mdw_version: to_string(version),
      mdw_revision: :persistent_term.get({:ae_mdw, :build_revision}),
      mdw_height: mdw_height,
      mdw_tx_index: mdw_tx_index,
      mdw_async_tasks: async_tasks_counters,
      mdw_synced: node_height == mdw_height,
      mdw_syncing: mdw_syncing?,
      mdw_gens_per_minute: round(gens_per_minute * 100) / 100
    }
  end

  defp safe_mdw_tx_index_and_height(state) do
    case Util.last_txi(state) do
      {:ok, last_txi} ->
        mdw_height = Util.synced_height(state)

        {last_txi, mdw_height}

      :none ->
        {0, 0}
    end
  end

  defp calculate_gens_per_min(0, gens_per_min), do: gens_per_min

  defp calculate_gens_per_min(prev_gens_per_min, gens_per_min),
    # exponential moving average
    do: (1 - @gens_per_min_weight) * prev_gens_per_min + @gens_per_min_weight * gens_per_min
end
