defmodule AeMdw.Db.Sync do
  alias __MODULE__
  alias Sync.{BlockIndex, Transaction}
  alias AeMdw.Db.Model

  require Logger
  require Model

  import AeMdw.{Sigil, Db.Util}

  use GenServer

  defstruct [:pid, :fork, :tx_context]

  @verify_range_kbs 200

  ################################################################################

  def start_link(_),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    :aec_events.subscribe(:chain)
    {:ok, %Sync{}, {:continue, :start_sync}}
  end

  def handle_continue(:start_sync, %Sync{pid: nil} = s),
    do: {:noreply, spawn_action(s)}

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

  def handle_info({pid, _, {txi, rev_cache}}, %Sync{pid: pid, fork: nil} = s) do
    top_height = height(:top)
    bi_max_kbi = BlockIndex.max_kbi()
    is_synced? = bi_max_kbi == top_height
    next_state = %{s | pid: nil, tx_context: {txi, rev_cache}}
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
      rem(x, freq) == 0 && info(msg_fn.(x, acc))
      work_fn.(x, acc)
    end
  end

  ################################################################################

  defp spawn_action(%Sync{pid: nil, fork: nil, tx_context: tx_context} = s) do
    args = (tx_context && [height(:top) - 1, tx_context]) || [:safe]
    spawn_action({Transaction, :sync, args}, s)
  end

  defp spawn_action(%Sync{pid: nil, fork: height} = s) when not is_nil(height) do
    invalidate(height)
    spawn_action({Transaction, :sync, [:top]}, %{s | fork: nil})
  end

  defp spawn_action({m, f, a}, %Sync{} = s) do
    info("sync action #{inspect(hd(a))}")
    %{s | tx_context: nil, pid: spawn_link(fn -> run_action({m, f, a}) end)}
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

  defp invalidate(fork_height) when is_integer(fork_height) do
    prev_kbi = fork_height - 1
    from_txi = Model.block(read_block!({prev_kbi, -1}), :tx_index)

    cond do
      is_integer(from_txi) && from_txi >= 0 ->
        info("invalidating from tx #{from_txi} at generation #{prev_kbi}")
        bi_keys = BlockIndex.keys_range({fork_height - 1, 0})
        tx_keys = Transaction.keys_range(from_txi)
        all_keys = Map.merge(bi_keys, tx_keys)
        log_del_keys(all_keys)
        delete_records(all_keys)

      # wasn't synced up to that txi, nothing to do
      true ->
        :ok
    end
  end

  defp log_del_keys(tab_keys) do
    {blocks, tab_keys} = Map.pop(tab_keys, ~t[block])
    {txs, tab_keys} = Map.pop(tab_keys, ~t[tx])
    [b_count, t_count] = [blocks, txs] |> Enum.map(&Enum.count/1)
    {b1, b2} = {List.last(blocks), List.first(blocks)}
    {t1, t2} = {List.first(txs), List.last(txs)}
    info("table block has #{b_count} records to delete: #{inspect(b1)}..#{inspect(b2)}")
    info("table tx has #{t_count} records to delete: #{t1}..#{t2}")

    for {tab, keys} <- tab_keys,
        do: info("table #{Model.record(tab)} has #{Enum.count(keys)} records to delete")

    :ok
  end

  def info(msg),
    do: Logger.info(msg, sync: true)
end
