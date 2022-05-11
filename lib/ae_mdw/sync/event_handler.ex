defmodule AeMdw.Sync.EventHandler do
  @moduledoc """
  Module to functionally deal with all chain and process events than happen when
  syncing.

  E.g.
  ```
  handler = EventHandler.init()
  {:ok, handler2} = EventHandler.process_event({:new_height, 123456}, handler)

  """

  alias AeMdw.Blocks
  alias AeMdw.Db.DbStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Block
  alias AeMdw.Log
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.Server
  alias AeMdwWeb.Websocket.Broadcaster

  defstruct [
    :db_state,
    :mem_state,
    :db_pid,
    :mem_pid,
    :chain_height,
    :fork_height,
    :spawner,
    :restarts
  ]

  @type spawner() :: ((() -> any()) -> pid())
  @type event() ::
          {:pid_down, pid(), term()}
          | {:new_height, Blocks.height()}
          | {:fork, Blocks.height()}
          | {:mem_done, State.t()}
          | {:db_done, State.t()}
  @opaque t() :: %__MODULE__{
            db_state: State.t(),
            db_pid: pid() | nil,
            mem_state: State.t(),
            mem_pid: pid() | nil,
            chain_height: Blocks.height(),
            fork_height: Blocks.height() | nil,
            spawner: spawner(),
            restarts: non_neg_integer()
          }

  @max_restarts 4
  @mem_gens 1
  @max_sync_gens 6

  @spec init(Blocks.height(), State.t(), State.t(), spawner()) :: t()
  def init(chain_height, db_state, mem_state, spawner) do
    %__MODULE__{
      db_state: db_state,
      mem_state: mem_state,
      db_pid: nil,
      mem_pid: nil,
      chain_height: chain_height,
      fork_height: nil,
      spawner: spawner,
      restarts: 0
    }
  end

  @spec process_event(event(), t()) :: {:ok, t()} | :stop
  def process_event(event, state) do
    case handle_event(event, state) do
      {:ok, %__MODULE__{db_pid: db_pid, mem_pid: mem_pid} = new_state} ->
        db_pid = db_pid || spawn_db_sync(new_state)
        mem_pid = mem_pid || spawn_mem_sync(new_state)

        {:ok, %__MODULE__{new_state | db_pid: db_pid, mem_pid: mem_pid}}

      :no_change ->
        {:ok, state}

      :stop ->
        :stop
    end
  end

  @spec process_event!(event(), t()) :: t()
  def process_event!(event, state) do
    {:ok, new_state} = process_event(event, state)

    new_state
  end

  ## getters
  @spec current_height(t()) :: Blocks.height()
  def current_height(%__MODULE__{db_state: db_state, mem_state: mem_state}),
    do: max(State.height(db_state), State.height(mem_state))

  # **events_handling**
  defp handle_event({:fork, new_fork_height}, %__MODULE__{fork_height: old_fork_height} = state) do
    fork_height = (old_fork_height && min(old_fork_height, new_fork_height)) || new_fork_height

    {:ok, %__MODULE__{state | fork_height: fork_height}}
  end

  defp handle_event({:new_height, chain_height}, state),
    do: {:ok, %__MODULE__{state | chain_height: chain_height}}

  defp handle_event({:pid_down, _pid, reason}, %__MODULE__{restarts: restarts})
       when restarts >= @max_restarts do
    Log.info("Sync.Server error: #{inspect(reason)}. Stopping...")

    :stop
  end

  defp handle_event(
         {:pid_down, pid, reason},
         %__MODULE__{db_pid: pid, restarts: restarts} = state
       ) do
    Log.info("DB Sync.Server error: #{inspect(reason)}")

    {:ok, %__MODULE__{state | db_pid: nil, restarts: restarts + 1}}
  end

  defp handle_event(
         {:pid_down, pid, reason},
         %__MODULE__{mem_pid: pid, restarts: restarts} = state
       ) do
    Log.info("Mem Sync.Server error: #{inspect(reason)}")

    {:ok, %__MODULE__{state | mem_pid: nil, restarts: restarts + 1}}
  end

  defp handle_event({:mem_done, new_mem_state}, state),
    do: {:ok, %__MODULE__{state | mem_state: new_mem_state, mem_pid: nil}}

  defp handle_event({:db_done, new_db_state}, state),
    do: {:ok, %__MODULE__{state | db_state: new_db_state, db_pid: nil}}

  defp handle_event(_evt, _state), do: :no_change

  defp spawn_db_sync(%__MODULE__{spawner: spawner, db_state: db_state, chain_height: chain_height}) do
    if State.height(db_state) < chain_height - @mem_gens do
      from_height = State.height(db_state) + 1
      to_height = min(from_height + @max_sync_gens - 1, chain_height - @mem_gens)
      from_txi = Block.next_txi(db_state)

      from_mbi =
        case Block.last_synced_mbi(db_state, from_height) do
          {:ok, mbi} -> mbi + 1
          :none -> -1
        end

      spawn_db_sync(spawner, db_state, from_height, from_mbi, from_txi, to_height)
    end
  end

  defp spawn_db_sync(spawner, db_state, from_height, from_mbi, from_txi, to_height) do
    spawner.(fn ->
      {mutations_time, {gens_mutations, _next_txi}} =
        :timer.tc(fn ->
          Block.blocks_mutations(from_height, from_mbi, from_txi, to_height)
        end)

      {exec_time, new_state} = :timer.tc(fn -> exec_db_mutations(gens_mutations, db_state) end)

      gens_per_min = (to_height + 1 - from_height) * 60_000_000 / (mutations_time + exec_time)

      Server.done_db(new_state, gens_per_min)
    end)
  end

  defp spawn_mem_sync(%__MODULE__{
         mem_state: mem_state,
         db_state: db_state,
         fork_height: fork_height,
         chain_height: chain_height,
         spawner: spawner
       }) do
    db_height = State.height(db_state)
    mem_height = State.height(mem_state)

    if mem_height < chain_height and db_height == chain_height - @mem_gens do
      mem_state =
        if mem_height == db_height do
          State.set_global(State.new(MemStore.new(DbStore.new())))
        else
          if fork_height, do: State.invalidate(mem_state, fork_height), else: mem_state
        end

      from_height = mem_height + 1
      to_height = min(from_height + @max_sync_gens - 1, chain_height)
      from_txi = Block.next_txi(mem_state)

      from_mbi =
        case Block.last_synced_mbi(mem_state, from_height) do
          {:ok, mbi} -> mbi + 1
          :none -> -1
        end

      spawn_mem_sync(spawner, mem_state, from_height, from_txi, from_mbi, to_height)
    end
  end

  defp spawn_mem_sync(spawner, mem_state, from_height, from_txi, from_mbi, to_height) do
    spawner.(fn ->
      {mutations_time, {gens_mutations, _next_txi}} =
        :timer.tc(fn ->
          Block.blocks_mutations(from_height, from_mbi, from_txi, to_height)
        end)

      {exec_time, new_state} = :timer.tc(fn -> exec_mem_mutations(gens_mutations, mem_state) end)

      gens_per_min = (to_height + 1 - from_height) * 60_000_000 / (mutations_time + exec_time)

      Server.done_mem(new_state, gens_per_min)
    end)
  end

  defp exec_db_mutations(gens_mutations, state) do
    gens_mutations
    |> Enum.flat_map(fn {_height, blocks_mutations} -> blocks_mutations end)
    |> Enum.reduce(state, fn {{_height, mbi}, block, block_mutations}, state ->
      new_state = State.commit_db(state, block_mutations)

      Producer.commit_enqueued()

      broadcast_block(block, mbi == -1)

      new_state
    end)
  end

  defp exec_mem_mutations(gens_mutations, state) do
    gens_mutations
    |> Enum.flat_map(fn {_height, blocks_mutations} -> blocks_mutations end)
    |> Enum.reduce(state, fn {{_height, mbi}, block, block_mutations}, state ->
      new_state = State.commit_mem(state, block_mutations)

      broadcast_block(block, mbi == -1)

      new_state
    end)
  end

  defp broadcast_block(block, is_key?) do
    if is_key? do
      Broadcaster.broadcast_key_block(block, :mdw)
    else
      Broadcaster.broadcast_micro_block(block, :mdw)
      Broadcaster.broadcast_txs(block, :mdw)
    end
  end
end
