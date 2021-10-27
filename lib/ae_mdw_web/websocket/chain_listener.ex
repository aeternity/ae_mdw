defmodule AeMdwWeb.Websocket.ChainListener do
  @moduledoc """
  Listens to chain events when the top block has changed.
  """
  use GenServer

  alias AeMdw.Log

  alias AeMdwWeb.Websocket.Broadcaster

  require Ex2ms
  require Logger

  @subs_main :subs_main
  @subs_pids :subs_pids
  @subs_channel_targets :subs_channel_targets
  @subs_target_channels :subs_target_channels

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_arg), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl GenServer
  def init(state) do
    :ets.foldl(fn {k, _v}, acc -> [k | acc] end, [], @subs_pids) |> Enum.each(&register/1)
    :aec_events.subscribe(:top_changed)
    {:ok, state}
  end

  @spec register(pid()) :: :ok
  def register(pid), do: GenServer.cast(__MODULE__, {:monitor, pid})

  @impl GenServer
  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :micro} = info}}, state) do
    case :aehttp_logic.get_micro_block_by_hash(info.block_hash) do
      {:ok, block} ->
        Broadcaster.broadcast_micro_block(block, :node)
        Broadcaster.broadcast_txs(block, :node)

      {:error, :block_not_found} ->
        Log.warn("gproc_ps_event with block not found: block_hash = #{inspect(info.block_hash)}")
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :key} = info}}, state) do
    case :aec_chain.get_key_block_by_height(info.height) do
      {:ok, block} ->
        Broadcaster.broadcast_key_block(block, :node)

      {:error, _rsn} ->
        Log.warn("gproc_ps_event with block not found: block_hash = #{inspect(info.block_hash)}")
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, _type, pid, _info}, state) do
    case :ets.member(@subs_main, pid) do
      true ->
        # main socket channel dies, all connections are disconnected. Clean all tables.
        Enum.each(
          [@subs_main, @subs_channel_targets, @subs_target_channels, @subs_pids],
          &:ets.delete_all_objects/1
        )

      false ->
        spec =
          Ex2ms.fun do
            {{^pid, sub}, _} -> sub
          end

        for sub <- :ets.select(@subs_channel_targets, spec) do
          key_to_delete = {sub, pid}
          :ets.delete(@subs_target_channels, key_to_delete)
        end

        spec_ =
          Ex2ms.fun do
            {{^pid, _}, _} -> true
          end

        :ets.select_delete(@subs_channel_targets, spec_)
        :ets.delete(@subs_pids, pid)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:monitor, pid}, state) do
    Process.monitor(pid)
    {:noreply, state}
  end
end
