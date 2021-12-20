defmodule AeMdw.Db.Sync.ChainSubscriber do
  @moduledoc """
  Listens to sync chain events and spawns processes to sync until the height notified.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.BlockIndex
  alias AeMdw.Db.Sync.Invalidate
  alias AeMdw.Db.Sync.Transaction
  alias AeMdw.Log
  alias AeMdw.Sync.Watcher
  alias __MODULE__, as: State

  @typep state :: %State{
           pid: pid() | nil,
           fork: integer() | nil
         }

  defstruct [:pid, :fork]

  require Model

  import AeMdw.Node.Chain, only: [top_height: 0]

  @verify_range_kbs 200

  ################################################################################

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @spec init([]) :: {:ok, state(), {:continue, :start_sync}}
  @impl GenServer
  def init([]) do
    :ets.delete_all_objects(:stat_sync_cache)
    :aec_events.subscribe(:chain)
    Watcher.notify_sync(self())
    {:ok, %State{}, {:continue, :start_sync}}
  end

  @impl GenServer
  def handle_continue(:start_sync, %State{pid: nil} = s),
    do: {:noreply, spawn_action({Transaction, :sync, [safe_height()]}, s)}

  @impl GenServer
  def handle_info({:fork, height}, %State{pid: pid} = s) when is_integer(height) do
    s = %{s | fork: fork_height(height, s.fork)}
    {:noreply, (pid && s) || spawn_action(s)}
  end

  @impl GenServer
  def handle_info({_, :chain, %{info: {:fork, header}}}, %State{} = s),
    do: handle_info({:fork, :aec_headers.height(header)}, s)

  @impl GenServer
  def handle_info({_, :chain, %{info: {:generation, _}}}, %State{pid: pid} = s),
    do: {:noreply, (pid && s) || spawn_action(s)}

  @impl GenServer
  def handle_info({pid, _act, _res}, %State{pid: pid, fork: fork} = s) when not is_nil(fork),
    do: {:noreply, spawn_action(%{s | pid: nil})}

  @impl GenServer
  def handle_info({pid, _, _next_txi}, %State{pid: pid, fork: nil} = s) do
    bi_max_kbi = BlockIndex.max_kbi()
    is_synced? = bi_max_kbi == top_height()
    next_state = %{s | pid: nil}
    {:noreply, (is_synced? && next_state) || spawn_action(next_state)}
  end

  #
  # Private functions
  #
  defp safe_height(),
    do: max(0, top_height() - @verify_range_kbs)

  defp spawn_action(%State{pid: nil, fork: nil} = s),
    do: spawn_action({Transaction, :sync, [top_height() - 1]}, s)

  defp spawn_action(%State{pid: nil, fork: height} = s) when not is_nil(height) do
    Log.info("invalidation #{height}")
    Invalidate.invalidate(height)
    spawn_action({Transaction, :sync, [top_height()]}, %{s | fork: nil})
  end

  defp spawn_action({m, f, a}, %State{} = s) do
    Log.info("sync action #{inspect(hd(a))}")
    %{s | pid: spawn_link(fn -> run_action({m, f, a}) end)}
  end

  defp run_action({m, f, a} = action) do
    result = apply(m, f, a)
    send(__MODULE__, {self(), action, result})
  end

  defp fork_height(height1, height2) when is_integer(height1) do
    case {height1, height2} do
      {_, nil} -> height1
      {h1, h2} -> min(h1, h2)
    end
  end
end
