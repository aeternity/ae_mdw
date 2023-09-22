defmodule AeMdw.Sync.AsyncStoreServer do
  @moduledoc """
  Synchronizes writing the result of async tasks to AsyncStore with the writes to State
  having the AsyncStore as the source of mutations during database commit.

  Since async tasks completion time is unknown, writing AsyncStore records to disk
  needs to be synchronized with `AeMdw.Sync.Server` commit. If the block related to
  the async task was already commited to database, the async task result is not written
  to AsyncStore but persisted direclty.
  """
  use GenServer

  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks.WealthRank

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec init(:ok) :: {:ok, %{last_db_kbi: AeMdw.Blocks.height()}}
  @impl GenServer
  def init(:ok) do
    {:ok, %{last_db_kbi: 0}}
  end

  @spec write_mutations([Mutation.t()], fun()) :: :ok
  def write_mutations(async_mutations, done_fn) do
    GenServer.cast(__MODULE__, {:write_mutations, async_mutations, done_fn})
  end

  @spec write_mutations_without_async([Mutation.t()], fun()) :: :ok
  def write_mutations_without_async(async_mutations, done_fn) do
    GenServer.cast(__MODULE__, {:write_mutations_without_async, async_mutations, done_fn})
  end

  @spec write_async_store(State.t()) :: State.t()
  def write_async_store(db_state) do
    GenServer.call(__MODULE__, {:write_store, db_state}, 60_000)
  end

  @impl GenServer
  def handle_cast({:write_mutations, mutations, done_fn}, state) do
    async_state = State.new(AsyncStore.instance())

    mutations
    |> Enum.reject(&is_nil/1)
    |> Enum.each(&Mutation.execute(&1, async_state))

    done_fn.()

    {:noreply, state}
  end

  def handle_cast({:write_mutations_without_async, mutations, done_fn}, state) do
    _new_state = State.commit_db_without_async(State.new(), mutations)

    done_fn.()

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:write_store, db_state1}, _from, state) do
    {top_keys, store} = WealthRank.prune_balance_ranking(AsyncStore.instance())

    db_state2 =
      store
      |> AsyncStore.mutations()
      |> Enum.reduce(db_state1, &Mutation.execute/2)

    AsyncStore.clear(AsyncStore.instance())

    _store = WealthRank.restore_ranking(AsyncStore.instance(), top_keys)

    {:reply, db_state2, state}
  end
end
