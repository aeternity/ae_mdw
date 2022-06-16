defmodule AeMdw.Sync.Watcher do
  @moduledoc """
  Subscribes to chain events for dealing with new blocks and block
  invalidations, and sends them to the syncing server.

  There's one valid message that arrives from core that we send to the
  syncing server is if there's a new key block added or if the head of the
  chain was changed, where we simply send the new height.
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

    Server.new_height(chain_height(), chain_hash())

    {:noreply, state}
  end

  @impl true
  @spec handle_info(term(), t()) :: {:noreply, t()}
  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :key}}}, state) do
    Server.new_height(chain_height(), chain_hash())

    {:noreply, state}
  end

  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :micro}}}, state) do
    Server.new_height(chain_height(), chain_hash())

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp chain_height, do: :aec_headers.height(:aec_chain.top_header())

  defp chain_hash do
    {:ok, block_hash} =
      :aec_chain.top_block() |> :aec_blocks.to_header() |> :aec_headers.hash_header()

    block_hash
  end
end
