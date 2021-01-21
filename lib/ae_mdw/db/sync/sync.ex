defmodule AeMdw.Db.Sync do
  alias __MODULE__
  alias Sync.{BlockIndex, Transaction, Invalidate}
  alias AeMdw.Log
  alias AeMdw.Db.Model

  require Model

  use GenServer

  defstruct [:pid, :fork]

  @verify_range_kbs 200

  ################################################################################

  def start_link(_),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    :aec_events.subscribe(:chain)
    {:ok, %Sync{}, {:continue, :start_sync}}
  end

  def handle_continue(:start_sync, %Sync{pid: nil} = s),
    do: {:noreply, spawn_action({Transaction, :sync, [:safe]}, s)}

  def handle_info({:fork, height}, %Sync{pid: pid} = s) when is_integer(height) do
    s = %{s | fork: fork_height(height, s.fork)}
    {:noreply, (pid && s) || spawn_action(s)}
  end

  def handle_info({_, :chain, %{info: {:fork, header}}}, %Sync{} = s),
    do: handle_info({:fork, :aec_headers.height(header)}, s)

  def handle_info({_, :chain, %{info: {:generation, _}}}, %Sync{pid: pid} = s),
    do: {:noreply, (pid && s) || spawn_action(s)}

  def handle_info({pid, _act, _res}, %Sync{pid: pid, fork: fork} = s) when not is_nil(fork),
    do: {:noreply, spawn_action(%{s | pid: nil})}

  def handle_info({pid, _, _next_txi}, %Sync{pid: pid, fork: nil} = s) do
    top_height = height(:top)
    bi_max_kbi = BlockIndex.max_kbi()
    is_synced? = bi_max_kbi == top_height
    next_state = %{s | pid: nil}
    {:noreply, (is_synced? && next_state) || spawn_action(next_state)}
  end

  ##########

  def safe_height(top_height),
    do: max(0, top_height - @verify_range_kbs)

  def height(:top),
    do: :aec_headers.height(:aec_chain.top_header())

  def height(:safe),
    do: safe_height(height(:top))

  def height(i) when is_integer(i) and i >= 0 do
    top = height(:top)
    i <= top || raise RuntimeError, message: "no such generation: #{i} (max = #{top})"
    i
  end

  def progress_logger(work_fn, freq, msg_fn) do
    fn x, acc ->
      rem(x, freq) == 0 && Log.info(msg_fn.(x, acc))
      work_fn.(x, acc)
    end
  end

  ################################################################################

  defp spawn_action(%Sync{pid: nil, fork: nil} = s),
    do: spawn_action({Transaction, :sync, [height(:top) - 1]}, s)

  defp spawn_action(%Sync{pid: nil, fork: height} = s) when not is_nil(height) do
    Log.info("invalidation #{height}")
    Invalidate.invalidate(height)
    spawn_action({Transaction, :sync, [:top]}, %{s | fork: nil})
  end

  defp spawn_action({m, f, a}, %Sync{} = s) do
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
