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

  alias AeMdw.Sync.EventHandler
  alias AeMdw.Db.DbStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.State

  use GenServer

  defstruct [:syncing?, :event_handler, :gens_per_min]

  @retry_time 3_600_000
  @gens_per_min_weight 0.1

  @type gens_per_min() :: number()
  @opaque t() :: %__MODULE__{
            syncing?: boolean(),
            event_handler: EventHandler.t(),
            gens_per_min: gens_per_min()
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

  @spec done_db(State.t(), gens_per_min()) :: :ok
  def done_db(state, gens_per_min),
    do: GenServer.cast(__MODULE__, {:done_db, state, gens_per_min})

  @spec done_mem(State.t(), gens_per_min()) :: :ok
  def done_mem(state, gens_per_min),
    do: GenServer.cast(__MODULE__, {:done_mem, state, gens_per_min})

  @impl true
  def init([]) do
    db_store = DbStore.new()
    mem_store = MemStore.new(db_store)

    db_state = State.new(db_store)
    mem_state = State.new(mem_store)

    event_handler = EventHandler.init(chain_height(), db_state, mem_state, &spawn_with_monitor/1)

    {:ok, %__MODULE__{syncing?: false, event_handler: event_handler, gens_per_min: 0}}
  end

  @impl true
  @spec handle_call(:syncing?, GenServer.from(), t()) :: {:reply, boolean(), t()}
  def handle_call(:syncing?, _from, %__MODULE__{syncing?: syncing?} = state) do
    {:reply, syncing?, state}
  end

  @impl true
  def handle_call(:gens_per_min, _from, %__MODULE__{gens_per_min: gens_per_min} = state),
    do: {:reply, gens_per_min, state}

  @impl true
  @spec handle_cast(:start_sync, t()) :: {:noreply, t()}
  @spec handle_cast({:done_db, State.t(), gens_per_min()}, t()) :: {:noreply, t()}
  @spec handle_cast({:done_mem, State.t(), gens_per_min()}, t()) :: {:noreply, t()}
  def handle_cast(:start_sync, %__MODULE__{event_handler: event_handler} = state) do
    :aec_events.subscribe(:chain)
    :aec_events.subscribe(:top_changed)

    event_handler = EventHandler.process_event!({:new_height, chain_height()}, event_handler)

    {:noreply, %__MODULE__{state | event_handler: event_handler, syncing?: true}}
  end

  @impl true
  def handle_cast(
        {:done_db, db_state, new_gens_per_min},
        %__MODULE__{event_handler: event_handler, gens_per_min: gens_per_min} = state
      ) do
    gens_per_min = calculate_gens_per_min(gens_per_min, new_gens_per_min)

    {:noreply,
     %__MODULE__{
       state
       | gens_per_min: gens_per_min,
         event_handler: EventHandler.process_event!({:db_done, db_state}, event_handler)
     }}
  end

  def handle_cast(
        {:done_mem, mem_state, new_gens_per_min},
        %__MODULE__{event_handler: event_handler, gens_per_min: gens_per_min} = state
      ) do
    gens_per_min = calculate_gens_per_min(gens_per_min, new_gens_per_min)

    {:noreply,
     %__MODULE__{
       state
       | gens_per_min: gens_per_min,
         event_handler: EventHandler.process_event!({:mem_done, mem_state}, event_handler)
     }}
  end

  @impl true
  @spec handle_info(term(), t()) :: {:noreply, t()}
  def handle_info(
        {:gproc_ps_event, :top_changed, %{info: %{block_type: :key, height: height}}},
        %__MODULE__{event_handler: event_handler} = s
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

        fork_height = :aec_headers.height(main_header)

        %__MODULE__{
          s
          | event_handler: EventHandler.process_event!({:fork, fork_height}, event_handler)
        }
      else
        s
      end

    {:noreply, new_state}
  end

  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :micro}}}, s),
    do: {:noreply, s}

  def handle_info(
        {:DOWN, _ref, :process, pid, reason},
        %__MODULE__{event_handler: event_handler} = state
      ) do
    case EventHandler.process_event({:pid_down, pid, reason}, event_handler) do
      {:ok, next_event_handler} ->
        {:noreply, %__MODULE__{state | event_handler: next_event_handler}}

      :stop ->
        :aec_events.unsubscribe(:chain)
        :aec_events.unsubscribe(:top_changed)

        :timer.apply_after(@retry_time, __MODULE__, :start_sync, [])

        {:noreply, %__MODULE__{state | syncing?: false}}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp chain_height, do: :aec_headers.height(:aec_chain.top_header())

  defp spawn_with_monitor(fun) do
    pid = spawn(fun)

    Process.monitor(pid)

    pid
  end

  defp calculate_gens_per_min(prev_gens_per_min, gens_per_min),
    # exponential moving average
    do: (1 - @gens_per_min_weight) * prev_gens_per_min + @gens_per_min_weight * gens_per_min
end
