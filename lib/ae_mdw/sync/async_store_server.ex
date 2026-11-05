defmodule AeMdw.Sync.AsyncStoreServer do
  @moduledoc """
  Synchronizes writing the result of async tasks to AsyncStore with the writes to State
  having the AsyncStore as the source of mutations during database commit.

  Since async tasks completion time is unknown, writing AsyncStore records to disk
  needs to be synchronized with `AeMdw.Sync.Server` commit. If the block related to
  the async task was already commited to database, the async task result is not written
  to AsyncStore but persisted direclty.

  AsyncStore reads don't fall back to the database, so a task can also pass flush
  mutations: they run against the database state right after the AsyncStore records
  are written to it. They run inside the commit, serialized with the blocks writing the
  same keys, so they have to stay small: the commit waits for them for up to 60 seconds.
  """
  use GenServer

  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.State

  @typep internal_state() :: %{
           async_store: AsyncStore.t(),
           last_db_kbi: AeMdw.Blocks.height(),
           flush_mutations: [Mutation.t()],
           flush_waiters: [GenServer.from()]
         }

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]) do
    GenServer.start_link(__MODULE__, %{async_store: AsyncStore.instance()}, name: __MODULE__)
  end

  @spec start_link(%{async_store: AsyncStore.t()}) :: GenServer.on_start()
  def start_link(%{async_store: async_store}) do
    GenServer.start_link(__MODULE__, %{async_store: async_store}, name: __MODULE__)
  end

  @spec init(%{async_store: AsyncStore.t()}) :: {:ok, internal_state()}
  @impl GenServer
  def init(%{async_store: async_store}) do
    {:ok, %{last_db_kbi: 0, async_store: async_store, flush_mutations: [], flush_waiters: []}}
  end

  @spec write_mutations([Mutation.t()], fun(), [Mutation.t()]) :: :ok
  def write_mutations(async_mutations, done_fn, flush_mutations \\ []) do
    GenServer.cast(__MODULE__, {:write_mutations, async_mutations, flush_mutations, done_fn})
  end

  @doc """
  Queues mutations to run in the next database commit and returns once they have run.
  """
  @spec flush_mutations([Mutation.t()]) :: :ok
  def flush_mutations(mutations) do
    GenServer.call(__MODULE__, {:flush_mutations, mutations}, :infinity)
  end

  @spec write_async_store(State.t()) :: State.t()
  def write_async_store(db_state) do
    GenServer.call(__MODULE__, {:write_store, db_state}, 60_000)
  end

  @impl GenServer
  def handle_cast(
        {:write_mutations, mutations, flush_mutations, done_fn},
        %{async_store: async_store, flush_mutations: pending_flush_mutations} = state
      ) do
    async_state = State.new(async_store)

    mutations
    |> Enum.reject(&is_nil/1)
    |> Enum.each(&Mutation.execute(&1, async_state))

    done_fn.()

    {:noreply, %{state | flush_mutations: pending_flush_mutations ++ flush_mutations}}
  end

  @impl GenServer
  def handle_call(
        {:flush_mutations, mutations},
        from,
        %{flush_mutations: pending_flush_mutations, flush_waiters: waiters} = state
      ) do
    {:noreply,
     %{
       state
       | flush_mutations: pending_flush_mutations ++ mutations,
         flush_waiters: [from | waiters]
     }}
  end

  def handle_call(
        {:write_store, db_state1},
        _from,
        %{async_store: async_store, flush_mutations: flush_mutations, flush_waiters: waiters} =
          state
      ) do
    db_state2 =
      async_store
      |> AsyncStore.mutations()
      |> Enum.concat(flush_mutations)
      |> Enum.reduce(db_state1, &Mutation.execute/2)

    AsyncStore.clear(async_store)
    Enum.each(waiters, &GenServer.reply(&1, :ok))

    {:reply, db_state2, %{state | flush_mutations: [], flush_waiters: []}}
  end
end
