defmodule AeMdwWeb.Websocket.ChainListener do
  @moduledoc """
  Listens to chain events when the top block has changed.
  """
  use GenServer

  alias AeMdw.Log

  alias AeMdwWeb.Websocket.Broadcaster

  require Logger

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_arg), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl GenServer
  def init(state) do
    :aec_events.subscribe(:top_changed)
    {:ok, state}
  end

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
        Broadcaster.broadcast_key_block(block, :v1, :node)
        Broadcaster.broadcast_key_block(block, :v2, :node)

      {:error, _rsn} ->
        Log.warn("gproc_ps_event with block not found: block_hash = #{inspect(info.block_hash)}")
    end

    {:noreply, state}
  end
end
