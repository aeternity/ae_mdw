defmodule AeMdw.Sync.Server do
  @moduledoc """
  Deals with all chain events sent by Watcher and syncing events built
  internally.

  State machine diagram:

                   ┌───────────┐
                   |  waiting  |
                   └─────┬─────┘
                         │ new_height(h)
                         ├──────────────────────────────┐
                         │                              │
                         │                ┌───────────┐ │done_db(new_state)
                         ▼             ┌► │syncing_db ├─┤
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
  alias AeMdw.Db.AccountActivityMutation
  alias AeMdw.Db.AccountCreationMutation
  alias AeMdw.Db.UpdateBalanceAccountMutation
  alias AeMdw.Db.RollbackMutation
  alias AeMdw.Log
  alias AeMdw.Node.Db
  alias AeMdw.Sync.AsyncTasks.WealthRankAccounts
  alias AeMdw.Sync.MemStoreCreator
  alias AeMdwWeb.Websocket.Broadcaster
  alias AeMdwWeb.Websocket.BroadcasterCache

  require Logger

  defstruct [:chain_height, :chain_hash, :db_state, :mem_hash, :restarts, :rollback?]

  @typep height() :: Blocks.height()
  @typep hash() :: Blocks.block_hash()
  @typep state() ::
           :waiting
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
  @typep cast_event() :: {:new_height, height(), hash()} | :start_sync | :restart_sync
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
  @internal_check_sync [{:next_event, :internal, :check_sync}]

  @spec task_supervisor() :: atom()
  def task_supervisor, do: @task_supervisor

  @spec start_link(GenServer.options()) :: :gen_statem.start_ret()
  def start_link(_opts), do: GenStateMachine.start_link(__MODULE__, [], name: __MODULE__)

  @spec start_sync() :: :ok
  def start_sync, do: GenStateMachine.cast(__MODULE__, :start_sync)

  @spec new_height(height(), hash()) :: :ok
  def new_height(height, hash), do: GenStateMachine.cast(__MODULE__, {:new_height, height, hash})

  @spec syncing?() :: boolean()
  def syncing?, do: :persistent_term.get({__MODULE__, :syncing?}, false)

  @spec restart_sync() :: :ok
  def restart_sync, do: GenStateMachine.cast(__MODULE__, :restart_sync)

  @spec rollback() :: :ok
  def rollback, do: GenStateMachine.cast(__MODULE__, :rollback)

  @impl true
  @spec init([]) :: :gen_statem.init_result(state())
  def init([]) do
    db_state = State.new()

    state_data = %__MODULE__{
      chain_height: nil,
      db_state: db_state,
      mem_hash: nil,
      restarts: 0,
      rollback?: false
    }

    {:ok, :waiting, state_data}
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
  def handle_event(:cast, :start_sync, :waiting, state_data) do
    {:next_state, :idle, state_data}
  end

  def handle_event(:cast, {:new_height, chain_height, chain_hash}, :waiting, state_data) do
    {:keep_state, %__MODULE__{state_data | chain_height: chain_height, chain_hash: chain_hash},
     @internal_check_sync}
  end

  def handle_event(:cast, {:new_height, chain_height, chain_hash}, _state, state_data) do
    {:keep_state, %__MODULE__{state_data | chain_height: chain_height, chain_hash: chain_hash},
     @internal_check_sync}
  end

  def handle_event(:cast, :rollback, _state, state_data),
    do: {:keep_state, %__MODULE__{state_data | rollback?: true}, @internal_check_sync}

  def handle_event(
        :internal,
        :check_sync,
        :idle,
        %__MODULE__{db_state: db_state, rollback?: true} = state
      ) do
    ref = spawn_db_rollback(db_state)

    state_data = %__MODULE__{
      state
      | rollback?: false,
        chain_height: nil,
        mem_hash: nil
    }

    {:next_state, {:syncing_db, ref}, state_data}
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
    new_state_data = %__MODULE__{
      state_data
      | mem_hash: State.height(new_db_state),
        db_state: new_db_state
    }

    Process.demonitor(ref, [:flush])

    {:next_state, :idle, new_state_data, @internal_check_sync}
  end

  def handle_event(:info, {ref, mem_hash}, {:syncing_mem, ref}, state_data) do
    new_state_data = %__MODULE__{state_data | mem_hash: mem_hash}
    {:next_state, :idle, new_state_data, @internal_check_sync}
  end

  def handle_event(:cast, :restart_sync, :stopped, state_data) do
    {:next_state, :idle, %__MODULE__{state_data | restarts: 0}, @internal_check_sync}
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

    {:next_state, :idle, %__MODULE__{state_data | restarts: restarts + 1}, @internal_check_sync}
  end

  def handle_event(
        :info,
        {:DOWN, ref, :process, _pid, reason},
        {:syncing_mem, ref},
        %__MODULE__{restarts: restarts} = state_data
      )
      when restarts < @max_restarts do
    Log.info("Mem Sync.Server error: #{inspect(reason)}")

    {:next_state, :idle, %__MODULE__{state_data | restarts: restarts + 1}, @internal_check_sync}
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
      gens_mutations = Block.blocks_mutations(from_height, from_mbi, from_txi, to_height, false)

      {exec_time, new_state} =
        :timer.tc(fn ->
          gens_mutations |> exec_db_mutations(db_state, clear_mem?) |> add_tx_fees_job()
        end)

      gens_per_min = (to_height + 1 - from_height) * 60_000_000 / exec_time
      Status.set_gens_per_min(gens_per_min)

      new_state
    end)
  end

  defp spawn_db_rollback(db_state) do
    spawn_task(fn ->
      gens_mutations = [RollbackMutation.new()]

      new_state = exec_db_mutations(gens_mutations, db_state, true)

      Status.set_gens_per_min(0)

      new_state
    end)
  end

  defp spawn_mem_sync(from_height, last_hash) do
    spawn_task(fn ->
      mem_state = State.create_mem_state()
      from_txi = Block.next_txi(mem_state)

      from_mbi =
        case Block.last_synced_mbi(mem_state, from_height) do
          {:ok, mbi} -> mbi + 1
          :none -> -1
        end

      gens_mutations = Block.blocks_mutations(from_height, from_mbi, from_txi, last_hash, true)

      new_state =
        mem_state
        |> exec_mem_mutations(gens_mutations, from_height)
        |> add_tx_fees_job()

      :ok = MemStoreCreator.commit(new_state.store)

      last_hash
    end)
  end

  defp exec_db_mutations(gens_mutations, initial_state, clear_mem?) do
    new_state =
      gens_mutations
      |> Enum.reduce(initial_state, fn {height, blocks_mutations}, state ->
        blocks_mutations = maybe_add_accounts_balance_mutations(blocks_mutations)
        {ts, new_state} = :timer.tc(fn -> exec_db_height(state, blocks_mutations, clear_mem?) end)

        :ok = profile_sync("sync_db", height, ts, blocks_mutations)

        new_state
      end)

    broadcast_blocks(gens_mutations)

    new_state
  end

  defp exec_db_height(state, blocks_mutations, clear_mem?) do
    Enum.reduce(blocks_mutations, state, fn {_bi, _block, block_mutations}, state ->
      State.commit_db(state, block_mutations, clear_mem?)
    end)
  end

  defp maybe_add_accounts_balance_mutations(gen_mutations) do
    accounts_set =
      Enum.reduce(gen_mutations, MapSet.new(), fn
        {{_height, -1}, _block, _mutations}, set ->
          set

        {_block_index, mblock, mutations}, set ->
          MapSet.union(set, WealthRankAccounts.micro_block_accounts(mblock, mutations))
      end)

    if MapSet.size(accounts_set) > 0 do
      {block_index, mb_hash, mblock} = last_microblock(gen_mutations)

      account_balances_mutations =
        mb_hash
        |> get_balances_from_node(accounts_set)
        |> Enum.reduce([], fn {account_pk, balance}, acc ->
          [{block_index, mblock, UpdateBalanceAccountMutation.new(account_pk, balance)} | acc]
        end)

      time = Db.get_block_time(mb_hash)

      account_statistics_mutations =
        Enum.flat_map(accounts_set, fn pubkey ->
          [
            {block_index, mblock, AccountCreationMutation.new(pubkey, time)},
            {block_index, mblock, AccountActivityMutation.new(pubkey, time)}
          ]
        end)

      gen_mutations ++ account_balances_mutations ++ account_statistics_mutations
    else
      gen_mutations
    end
  end

  defp get_balances_from_node(block_hash, account_set) do
    with {:value, trees} <- :aec_db.find_block_state_partial(block_hash, true, [:accounts]),
         accounts_tree <- :aec_trees.accounts(trees) do
      get_balances(accounts_tree, account_set)
    end
  end

  defp get_balances(accounts_tree, account_set) do
    account_set
    |> MapSet.to_list()
    |> Enum.flat_map(fn pubkey ->
      case :aec_accounts_trees.lookup(pubkey, accounts_tree) do
        {:value, account} -> [{pubkey, :aec_accounts.balance(account)}]
        :none -> []
      end
    end)
  end

  defp last_microblock(blocks_mutations) do
    {block_index, mblock, _mutations} =
      blocks_mutations
      |> Enum.filter(fn {{_height, mbi}, _block, _mutations} -> mbi != -1 end)
      |> Enum.max_by(fn {block_index, _block, _mutations} -> block_index end)

    {:ok, mb_hash} = :aec_headers.hash_header(:aec_blocks.to_micro_header(mblock))

    {block_index, mb_hash, mblock}
  end

  defp exec_mem_mutations(empty_state, gens_mutations, from_height) do
    # start syncing from memory, then anticipates commit to avoid committing only after 10 gens
    if from_height == AeMdw.Db.Util.synced_height(State.mem_state()) do
      Enum.reduce(gens_mutations, empty_state, fn {height, gen_mutations}, state ->
        gen_mutations = maybe_add_accounts_balance_mutations(gen_mutations)

        {ts, commited_state} =
          :timer.tc(fn ->
            mutations =
              Enum.map(gen_mutations, fn {_block_index, _mb, block_mutations} ->
                block_mutations
              end)

            State.commit_mem(state, mutations)
          end)

        :ok = profile_sync("sync_mem", height, ts, gen_mutations)

        commited_state
      end)
    else
      exec_all_mem_mutations(empty_state, gens_mutations)
    end
  end

  defp exec_all_mem_mutations(state, gens_mutations) do
    blocks_mutations =
      gens_mutations
      |> Enum.flat_map(fn {_height, blocks_mutations} -> blocks_mutations end)
      |> maybe_add_accounts_balance_mutations()

    {{height, _mbi}, _block, _mutations} = List.last(blocks_mutations)
    Log.info("[sync_mem] exec until height=#{height}")

    {ts, new_state} =
      :timer.tc(fn ->
        all_mutations =
          Enum.map(blocks_mutations, fn {_height, _block, mutations} -> mutations end)

        State.commit_mem(state, all_mutations)
      end)

    :ok = profile_sync("sync_mem", height, ts, blocks_mutations)

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

      Broadcaster.broadcast_key_block(key_block, :v1, :mdw, mbs_count, txs_count)
      Broadcaster.broadcast_key_block(key_block, :v2, :mdw, mbs_count, txs_count)
      Broadcaster.broadcast_key_block(key_block, :v3, :mdw, mbs_count, txs_count)

      Enum.each(mbs_mutations, fn {_block_index, micro_block, _mutations} ->
        Broadcaster.broadcast_micro_block(micro_block, :mdw)
        Broadcaster.broadcast_txs(micro_block, :mdw)
      end)
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

  defp profile_sync(sync_type, height, exec_ts, blocks_mutations) do
    mutations = Enum.map(blocks_mutations, &elem(&1, 2))

    _lookup_return =
      with [{_key, dryrun_ts}] <- :ets.lookup(:sync_profiling, {:dryrun, height}),
           [{_key, txs_ts}] <- :ets.lookup(:sync_profiling, {:txs, height}) do
        true = :ets.delete(:sync_profiling, {:dryrun, height - 1})
        true = :ets.delete(:sync_profiling, {:txs, height - 1})

        mutations_map =
          mutations
          |> List.flatten()
          |> Enum.reject(&is_nil/1)
          |> Enum.frequencies_by(fn
            %mod{} -> mod
            nil -> nil
          end)

        mutations_count = length(mutations)

        Log.info(
          "[#{sync_type}] height=#{height}, exec=#{div(exec_ts, 1_000)}ms, txs=#{div(txs_ts, 1_000)}ms, dryrun=#{div(dryrun_ts, 1_000)}ms, mutations={#{mutations_count}, #{inspect(mutations_map)}}"
        )
      end

    :ok
  end

  defp add_tx_fees_job(state) do
    now = :aeu_time.now_in_msecs()
    State.enqueue(state, :update_tx_stats, [now])
  end
end
