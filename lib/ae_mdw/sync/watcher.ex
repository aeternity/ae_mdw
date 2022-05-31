defmodule AeMdw.Sync.Watcher do
  @moduledoc """
  Subscribes to chain events for dealing with new blocks and block
  invalidations, and sends them to the syncing server.

  There's two valid messages that arrive from core that we send to the
  syncing server, plus 1 message that we handle internally:
  * If there's a new key block added, we send the new height.
  * If there's a new fork, we send `fork_height` to be the (height - 1)
    that we need to revert to.
  """

  alias AeMdw.Sync.Server

  use GenServer

  defstruct []

  @typep t() :: %__MODULE__{}

  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(_opts),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @spec start_sync() :: :ok
  def start_sync, do: GenServer.cast(__MODULE__, :start_sync)

  @impl true
  def init([]), do: {:ok, %__MODULE__{}}

  @impl true
  @spec handle_cast(:start_sync, t()) :: {:noreply, t()}
  def handle_cast(:start_sync, state) do
    :aec_events.subscribe(:chain)
    :aec_events.subscribe(:top_changed)

    Server.new_height(chain_height())

    {:noreply, state}
  end

  @impl true
  @spec handle_info(term(), t()) :: {:noreply, t()}
  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :key}}}, state) do
    Server.new_height(chain_height())

    {:noreply, state}
  end

  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :micro}}}, state),
    do: {:noreply, state}

  def handle_info(_msg, state), do: {:noreply, state}

  defp chain_height, do: :aec_headers.height(:aec_chain.top_header())
end
