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

  @spec node_and_mdw_status(State.t()) :: map()
  def node_and_mdw_status(state) do
    {:ok, top_kb} = :aec_chain.top_key_block()
    {node_syncing?, node_progress} = :aec_sync.sync_progress()
    node_height = :aec_blocks.height(top_kb)
    {mdw_tx_index, mdw_height} = safe_mdw_tx_index_and_height(state)
    mdw_syncing? = Server.syncing?()
    {:ok, version} = :application.get_key(:ae_mdw, :vsn)
    async_tasks_counters = Stats.counters()
    gens_per_minute = Server.gens_per_min()

    %{
      node_version: :aeu_info.get_version(),
      node_revision: :aeu_info.get_revision(),
      node_height: node_height,
      node_syncing: node_syncing?,
      node_progress: node_progress,
      mdw_version: to_string(version),
      mdw_revision: :persistent_term.get({:ae_mdw, :build_revision}),
      mdw_height: mdw_height,
      mdw_tx_index: mdw_tx_index,
      mdw_async_tasks: async_tasks_counters,
      # MDW is always 1 generation behind
      mdw_synced: node_height == mdw_height + 1,
      mdw_syncing: mdw_syncing?,
      mdw_gens_per_minute: round(gens_per_minute * 100) / 100
    }
  end

  defp safe_mdw_tx_index_and_height(state) do
    case Util.last_txi(state) do
      {:ok, last_txi} ->
        {mdw_height, _mbi} = state |> Util.read_tx!(last_txi) |> Model.tx(:block_index)
        {last_txi, mdw_height}

      :none ->
        {0, 0}
    end
  end
end
