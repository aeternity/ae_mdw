defmodule AeMdw.Sync.Server do
  @moduledoc """
  Deals with all chain events sent by Watcher and syncing events built
  internally.

  State machine diagram:

                   ┌───────────┐
                   │initialized│
                   └─────┬─────┘
                         │new_height(h)
                         ├──────────────────────────────┐
                         │                              │
                         │                ┌───────────┐ │done_db(new_state)
                         ▼             ┌►│syncing_db ├─┤
   -new_height(h)┌──► ┌──┴─┐check_sync()│ └───────────┘ │
                 │    │idle├────────────┤               │
                 └─── └────┘            │ ┌───────────┐ │done_mem(new_state)
                        ▲               └►│syncing_mem├─┘
                        │ restart_sync()  └────────┬──┘
                        │                          │
                    ┌───┴────┐              DOWN   │
                    │stopped │ ◄───────────────────┘
                    └────────┘

  Notes:
  * The DOWN message will only trigger a state change to stopped once
    max_restarts is exceeeded.
  * check_sync will be triggered internally for any new_height, done_db,
    or done_mem event.
  """

  use GenStateMachine

  alias AeMdw.Blocks
  alias AeMdw.Db.State
  alias AeMdw.Db.Status
  alias AeMdw.Db.Sync.Block
  alias AeMdw.Log
  alias AeMdw.Sync.AsyncTasks.WealthRankAccounts
  alias AeMdwWeb.Websocket.Broadcaster
  alias AeMdwWeb.Websocket.BroadcasterCache

  require Logger

  defstruct [:chain_height, :chain_hash, :db_state, :mem_hash, :restarts]

  @typep height() :: Blocks.height()
  @typep hash() :: Blocks.block_hash()
  @typep state() ::
           :initialized
           | :idle
           | :stopped
           | {:syncing_db, reference()}
           | {:syncing_mem, reference()}
  @typep state_data() :: %__MODULE__{
           chain_height: height(),
           chain_hash: hash(),
           db_state: State.t(),
           mem_hash: height(),
           restarts: non_neg_integer()
         }
  @typep cast_event() :: {:new_height, height(), hash()} | :restart_sync
  @typep internal_event() :: :check_sync
  @typep call_event() :: :syncing?
  @typep reason() :: term()
  @typep info_event() ::
           {reference(), State.t()}
           | {reference(), height(), hash()}
           | {:DOWN, reference(), :process, pid(), reason()}

  @max_restarts 5
  @retry_time 3_600_000
  @mem_gens 10
  @max_sync_gens 6
  @task_supervisor __MODULE__.TaskSupervsor

  @spec task_supervisor() :: atom()
  def task_supervisor, do: @task_supervisor

  @spec start_link(GenServer.options()) :: :gen_statem.start_ret()
  def start_link(_opts), do: GenStateMachine.start_link(__MODULE__, [], name: __MODULE__)

  @spec new_height(height(), hash()) :: :ok
  def new_height(height, hash), do: GenStateMachine.cast(__MODULE__, {:new_height, height, hash})

  @spec syncing?() :: boolean()
  def syncing?, do: :persistent_term.get({__MODULE__, :syncing?}, false)

  @spec restart_sync() :: :ok
  def restart_sync, do: GenStateMachine.cast(__MODULE__, :restart_sync)

  @impl true
  @spec init([]) :: :gen_statem.init_result(state())
  def init([]) do
    db_state = State.new()

    state_data = %__MODULE__{
      chain_height: nil,
      db_state: db_state,
      mem_hash: nil,
      restarts: 0
    }

    {:ok, :initialized, state_data}
  end

  @impl true
  @spec handle_event(:cast, cast_event(), state(), state_data()) ::
          :gen_statem.event_handler_result(state())
  @spec handle_event(:call, call_event(), state(), state_data()) ::
          :gen_statem.event_handler_result(state())
  @spec handle_event(:info, info_event(), state(), state_data()) ::
          :gen_statem.event_handler_result(state())
  @spec handle_event(:internal, internal_event(), state(), state_data()) ::
          :gen_statem.event_handler_result(state())
  def handle_event(:cast, {:new_height, chain_height, chain_hash}, :initialized, state_data) do
    actions = [{:next_event, :internal, :check_sync}]

    {:next_state, :idle,
     %__MODULE__{state_data | chain_height: chain_height, chain_hash: chain_hash}, actions}
  end

  def handle_event(:cast, {:new_height, chain_height, chain_hash}, _state, state_data) do
    actions = [{:next_event, :internal, :check_sync}]

    {:keep_state, %__MODULE__{state_data | chain_height: chain_height, chain_hash: chain_hash},
     actions}
  end

  def handle_event(
        :internal,
        :check_sync,
        :idle,
        %__MODULE__{
          chain_height: chain_height,
          chain_hash: chain_hash,
          db_state: db_state,
          mem_hash: mem_hash
        } = state_data
      ) do
    max_db_height = chain_height - @mem_gens
    db_height = State.height(db_state)

    :persistent_term.put({__MODULE__, :syncing?}, true)

    cond do
      db_height < max_db_height ->
        from_height = db_height + 1
        to_height = min(from_height + @max_sync_gens - 1, max_db_height)
        clear_mem? = to_height != max_db_height

        ref = spawn_db_sync(db_state, from_height, to_height, clear_mem?)

        {:next_state, {:syncing_db, ref}, state_data}

      db_height >= max_db_height and mem_hash != chain_hash ->
        ref = spawn_mem_sync(db_height, chain_hash)

        {:next_state, {:syncing_mem, ref}, state_data}

      true ->
        :keep_state_and_data
    end
  end

  def handle_event(:internal, :check_sync, _state, _data), do: :keep_state_and_data

  def handle_event(:info, {ref, new_db_state}, {:syncing_db, ref}, state_data) do
    actions = [{:next_event, :internal, :check_sync}]

    new_state_data = %__MODULE__{
      state_data
      | mem_hash: State.height(new_db_state),
        db_state: new_db_state
    }

    Process.demonitor(ref, [:flush])

    {:next_state, :idle, new_state_data, actions}
  end

  def handle_event(:info, {ref, mem_hash}, {:syncing_mem, ref}, state_data) do
    actions = [{:next_event, :internal, :check_sync}]

    new_state_data = %__MODULE__{state_data | mem_hash: mem_hash}

    {:next_state, :idle, new_state_data, actions}
  end

  def handle_event({:call, from}, :syncing?, state, _data) do
    syncing? = state != :initialized and state != :stopped
    actions = [{:reply, from, syncing?}]

    {:keep_state_and_data, actions}
  end

  def handle_event(:cast, :restart_sync, :stopped, state_data) do
    actions = [{:next_event, :internal, :check_sync}]

    {:next_state, :idle, %__MODULE__{state_data | restarts: 0}, actions}
  end

  def handle_event(:info, {:DOWN, _ref, :process, _pid, :normal}, _state, _state_data),
    do: :keep_state_and_data

  def handle_event(
        :info,
        {:DOWN, ref, :process, _pid, reason},
        {:syncing_db, ref},
        %__MODULE__{restarts: restarts} = state_data
      )
      when restarts < @max_restarts do
    Log.info("DB Sync.Server error: #{inspect(reason)}")

    actions = [{:next_event, :internal, :check_sync}]

    {:next_state, :idle, %__MODULE__{state_data | restarts: restarts + 1}, actions}
  end

  def handle_event(
        :info,
        {:DOWN, ref, :process, _pid, reason},
        {:syncing_mem, ref},
        %__MODULE__{restarts: restarts} = state_data
      )
      when restarts < @max_restarts do
    Log.info("Mem Sync.Server error: #{inspect(reason)}")

    actions = [{:next_event, :internal, :check_sync}]

    {:next_state, :idle, %__MODULE__{state_data | restarts: restarts + 1}, actions}
  end

  def handle_event(:info, {:DOWN, _ref, :process, _pid, reason}, _state, state_data) do
    Log.info("Sync.Server error: #{inspect(reason)}. Stopping...")

    :persistent_term.put({__MODULE__, :syncing?}, false)

    {:ok, _ref} = :timer.apply_after(@retry_time, __MODULE__, :restart_sync, [])

    {:next_state, :stopped, state_data}
  end

  def handle_event(event_type, event_content, state, data) do
    super(event_type, event_content, state, data)
  end

  defp spawn_db_sync(db_state, from_height, to_height, clear_mem?) do
    from_txi = Block.next_txi(db_state)

    from_mbi =
      case Block.last_synced_mbi(db_state, from_height) do
        {:ok, mbi} -> mbi + 1
        :none -> 0
      end

    spawn_task(fn ->
      {mutations_time, {gens_mutations, _next_txi}} =
        :timer.tc(fn ->
          Block.blocks_mutations(from_height, from_mbi, from_txi, to_height)
        end)

      {exec_time, new_state} =
        :timer.tc(fn -> exec_db_mutations(gens_mutations, db_state, clear_mem?) end)

      gens_per_min = (to_height + 1 - from_height) * 60_000_000 / (mutations_time + exec_time)
      Status.set_gens_per_min(gens_per_min)

      new_state
    end)
  end

  defp spawn_mem_sync(from_height, last_hash) do
    spawn_task(fn ->
      mem_state = State.new_mem_state()
      from_txi = Block.next_txi(mem_state)

      from_mbi =
        case Block.last_synced_mbi(mem_state, from_height) do
          {:ok, mbi} -> mbi + 1
          :none -> -1
        end

      {mutations_time, {gens_mutations, _next_txi}} =
        :timer.tc(fn ->
          Block.blocks_mutations(from_height, from_mbi, from_txi, last_hash)
        end)

      {exec_time, _new_state} = :timer.tc(fn -> exec_mem_mutations(gens_mutations, mem_state) end)

      gens_per_min = length(gens_mutations) * 60_000_000 / (mutations_time + exec_time)
      Status.set_gens_per_min(gens_per_min)

      last_hash
    end)
  end

  defp exec_db_mutations(gens_mutations, state, clear_mem?) do
    blocks_mutations =
      Enum.flat_map(gens_mutations, fn {_height, blocks_mutations} -> blocks_mutations end)

    enqueue_state = maybe_enqueue_accounts_balance(state, blocks_mutations)

    new_state =
      Enum.reduce(blocks_mutations, enqueue_state, fn {_bi, _block, block_mutations}, state ->
        State.commit_db(state, block_mutations, clear_mem?)
      end)

    broadcast_blocks(gens_mutations)

    new_state
  end

  defp maybe_enqueue_accounts_balance(state, block_mutations) do
    accounts_set =
      Enum.reduce(block_mutations, MapSet.new(), fn
        {{_height, -1}, _block, _mutations}, set ->
          set

        {_block_index, mblock, mutations}, set ->
          MapSet.union(set, WealthRankAccounts.micro_block_accounts(mblock, mutations))
      end)

    if MapSet.size(accounts_set) > 0 do
      {block_index, mb_hash} = last_microblock(block_mutations)
      State.enqueue(state, :store_acc_balance, [mb_hash, block_index], [accounts_set])
    else
      state
    end
  end

  defp last_microblock(block_mutations) do
    {block_index, mblock, _mutations} =
      block_mutations
      |> Enum.filter(fn {{_height, mbi}, _block, _mutations} -> mbi != -1 end)
      |> Enum.max_by(fn {block_index, _block, _mutations} -> block_index end)

    {:ok, mb_hash} = :aec_headers.hash_header(:aec_blocks.to_micro_header(mblock))

    {block_index, mb_hash}
  end

  defp exec_mem_mutations(gens_mutations, state) do
    blocks_mutations =
      Enum.flat_map(gens_mutations, fn {_height, blocks_mutations} -> blocks_mutations end)

    all_mutations =
      Enum.flat_map(blocks_mutations, fn {_block_index, _block, block_mutations} ->
        block_mutations
      end)

    new_state =
      state
      |> maybe_enqueue_accounts_balance(blocks_mutations)
      |> State.commit_mem(all_mutations)

    broadcast_blocks(gens_mutations)

    new_state
  end

  defp spawn_task(fun) do
    %Task{ref: ref} = Task.Supervisor.async_nolink(@task_supervisor, fun)

    ref
  end

  defp broadcast_blocks(gens_mutations) do
    Enum.each(gens_mutations, fn {height, blocks_mutations} ->
      {mbs_mutations, [{{^height, -1}, key_block, _mutations}]} = Enum.split(blocks_mutations, -1)

      mbs_count = length(mbs_mutations)
      {:ok, kb_hash} = key_block |> :aec_blocks.to_key_header() |> :aec_headers.hash_header()
      txs_count = get_txs_count(kb_hash, mbs_mutations)

      Broadcaster.broadcast_key_block(key_block, :v2, :mdw, mbs_count, txs_count)

      Enum.each(mbs_mutations, fn {_block_index, micro_block, _mutations} ->
        Broadcaster.broadcast_micro_block(micro_block, :mdw)
        Broadcaster.broadcast_txs(micro_block, :mdw)
      end)

      Broadcaster.broadcast_key_block(key_block, :v1, :mdw, mbs_count, txs_count)
    end)
  end

  defp get_txs_count(kb_hash, mbs_mutations) do
    with nil <- BroadcasterCache.get_txs_count(kb_hash) do
      count =
        mbs_mutations
        |> Enum.map(fn {_block_index, micro_block, _mutations} ->
          length(:aec_blocks.txs(micro_block))
        end)
        |> Enum.sum()

      BroadcasterCache.put_txs_count(kb_hash, count)
      count
    end
  end
end
