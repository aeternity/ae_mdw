defmodule AeMdw.Sync.Server do
  @moduledoc """
  Subscribes to chain events for dealing with new blocks and block
  invalidations.

  Internally keeps track of the generations that have been synced.

  There's 1 valid messages that arrive from core that we handle, plus 1
  message that we handle internally:
  * `:top_changed` (new key block added) - If there's a fork, we mark
    `fork_height` to be the (height - 1) that we need to revert to.
  * `{:done, height}` - The latest height synced by mdw was updated to.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Block
  alias AeMdw.Db.Sync.Invalidate
  alias AeMdw.Log
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdwWeb.Websocket.Broadcaster

  require Model

  use GenServer

  defstruct [:sync_pid_ref, :fork_height, :current_height, :restarts, :syncing?, :gens_per_min]

  @unsynced_gens 1
  @max_restarts 5
  @retry_time 3_600_000
  @max_blocks_sync 15
  @gens_per_min_weight 0.1

  @opaque t() :: %__MODULE__{
            sync_pid_ref: nil | {pid(), reference()},
            fork_height: Blocks.height() | nil,
            current_height: Blocks.height() | -1,
            restarts: non_neg_integer(),
            syncing?: boolean(),
            gens_per_min: number()
          }

  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(_opts),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @spec start_sync() :: :ok
  def start_sync, do: GenServer.cast(__MODULE__, :start_sync)

  @spec gens_per_min() :: number()
  def gens_per_min, do: GenServer.call(__MODULE__, :gens_per_min)

  @spec syncing?() :: boolean()
  def syncing?, do: GenServer.call(__MODULE__, :syncing?)

  @impl true
  def init([]) do
    {:ok, %__MODULE__{restarts: 0, syncing?: false, gens_per_min: 0}}
  end

  @impl true
  @spec handle_call(:syncing?, GenServer.from(), t()) :: {:reply, boolean(), t()}
  def handle_call(:syncing?, _from, %__MODULE__{syncing?: syncing?} = state) do
    {:reply, syncing?, state}
  end

  @impl true
  def handle_call(:gens_per_min, _from, %__MODULE__{gens_per_min: gens_per_min} = state) do
    {:reply, gens_per_min, state}
  end

  @impl true
  @spec handle_cast(:start_sync, t()) :: {:noreply, t()}
  @spec handle_cast({:done, Blocks.height()}, t()) :: {:noreply, t()}
  def handle_cast(:start_sync, state) do
    :aec_events.subscribe(:chain)
    :aec_events.subscribe(:top_changed)

    current_height = Block.synced_height()

    {:noreply,
     process_state(%__MODULE__{
       state
       | current_height: current_height,
         syncing?: true,
         restarts: 0,
         gens_per_min: 0
     })}
  end

  @impl true
  def handle_cast(
        {:done, height, gens_per_min},
        %__MODULE__{gens_per_min: prev_gens_per_min} = state
      ) do
    new_state =
      process_state(%__MODULE__{
        state
        | current_height: height,
          sync_pid_ref: nil,
          gens_per_min: calculate_gens_per_min(prev_gens_per_min, gens_per_min)
      })

    {:noreply, new_state}
  end

  @impl true
  @spec handle_info(term(), t()) :: {:noreply, t()}
  def handle_info(
        {:gproc_ps_event, :top_changed, %{info: %{block_type: :key, height: height}}},
        %__MODULE__{fork_height: old_fork_height} = s
      ) do
    header_candidates =
      height
      |> :aec_db.find_headers_at_height()
      |> Enum.filter(&(:aec_headers.type(&1) == :key))

    new_state =
      if length(header_candidates) > 1 do
        # FORK!
        main_header =
          Enum.find_value(header_candidates, fn header ->
            {:ok, header_hash} = :aec_headers.hash_header(header)

            # COSTLY!
            :aec_chain_state.hash_is_in_main_chain(header_hash) && header
          end)

        new_fork_height = :aec_headers.height(main_header)

        fork_height =
          (old_fork_height && min(old_fork_height, new_fork_height)) || new_fork_height

        %__MODULE__{s | fork_height: fork_height}
      else
        s
      end

    {:noreply, process_state(new_state)}
  end

  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :micro}}}, s),
    do: {:noreply, s}

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %__MODULE__{sync_pid_ref: {pid, ref}, restarts: restarts} = s
      )
      when restarts < @max_restarts do
    Log.info("Sync.Server error: #{inspect(reason)}")

    current_height = Block.synced_height()

    {:noreply,
     process_state(%__MODULE__{
       s
       | restarts: restarts + 1,
         sync_pid_ref: nil,
         current_height: current_height
     })}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, %__MODULE__{sync_pid_ref: {pid, ref}} = s) do
    Log.info("Sync.Server error: #{inspect(reason)}. Stopping..")

    :aec_events.unsubscribe(:chain)
    :aec_events.unsubscribe(:top_changed)

    :timer.apply_after(@retry_time, __MODULE__, :start_sync, [])

    {:noreply, process_state(%__MODULE__{s | syncing?: false, sync_pid_ref: nil})}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @spec process_state(t()) :: t()
  defp process_state(
         %__MODULE__{
           current_height: current_height,
           sync_pid_ref: nil,
           fork_height: fork_height,
           syncing?: true
         } = s
       ) do
    top_height = height() - @unsynced_gens

    sync_pid =
      cond do
        not is_nil(fork_height) and fork_height <= current_height ->
          spawn_invalidate(fork_height)

        current_height < top_height ->
          spawn_sync(
            current_height + 1,
            min(current_height + @max_blocks_sync, top_height)
          )

        true ->
          nil
      end

    sync_pid_ref = if sync_pid, do: {sync_pid, Process.monitor(sync_pid)}, else: nil

    %__MODULE__{s | sync_pid_ref: sync_pid_ref, fork_height: nil}
  end

  defp process_state(s), do: s

  defp spawn_sync(from_height, to_height) do
    from_mbi =
      case Block.last_synced_mbi(from_height) do
        {:ok, mbi} -> mbi + 1
        :none -> -1
      end

    db_state = State.new()
    from_txi = Block.next_txi()

    spawn(fn ->
      {mutations_time, {blocks_mutations, _next_txi}} =
        :timer.tc(fn ->
          Block.blocks_mutations(from_height, from_mbi, from_txi, to_height)
        end)

      {exec_time, _new_state} =
        :timer.tc(fn ->
          Enum.reduce(blocks_mutations, db_state, fn {block_index, block, mutations}, state ->
            commit_mutations(state, block_index, block, mutations)
          end)
        end)

      gens_per_min = (to_height + 1 - from_height) * 60_000_000 / (mutations_time + exec_time)

      GenServer.cast(__MODULE__, {:done, to_height, gens_per_min})
    end)
  end

  defp spawn_invalidate(height) do
    spawn(fn ->
      Log.info("invalidation #{height}")
      Invalidate.invalidate(height)

      GenServer.cast(__MODULE__, {:done, height - 1, 0})
    end)
  end

  defp height, do: :aec_headers.height(:aec_chain.top_header())

  defp commit_mutations(state, {_height, mbi}, block, mutations) do
    new_state = State.commit(state, mutations)

    Producer.commit_enqueued()

    if mbi == -1 do
      Broadcaster.broadcast_key_block(block, :mdw)
    else
      Broadcaster.broadcast_micro_block(block, :mdw)
      Broadcaster.broadcast_txs(block, :mdw)
    end

    new_state
  end

  defp calculate_gens_per_min(prev_gens_per_min, gens_per_min) do
    # exponential moving average
    (1 - @gens_per_min_weight) * prev_gens_per_min + @gens_per_min_weight * gens_per_min
  end
end
