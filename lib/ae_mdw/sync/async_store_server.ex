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
    GenServer.start_link(__MODULE__, %{async_store: AsyncStore.instance()}, name: __MODULE__)
  end

  @spec start_link(%{async_store: AsyncStore.t()}) :: GenServer.on_start()
  def start_link(%{async_store: %AsyncStore{} = async_store}) do
    GenServer.start_link(__MODULE__, %{async_store: async_store}, name: __MODULE__)
  end

  @spec init(AsyncStore.t()) :: {:ok, %{last_db_kbi: AeMdw.Blocks.height()}}
  @impl GenServer
  def init(%{async_store: %AsyncStore{} = async_store}) do
    {:ok, %{last_db_kbi: 0, async_store: async_store}}
  end

  @spec write_mutations([Mutation.t()], fun()) :: :ok
  def write_mutations(async_mutations, done_fn) do
    GenServer.cast(__MODULE__, {:write_mutations, async_mutations, done_fn})
  end

  @spec write_async_store(State.t()) :: State.t()
  def write_async_store(db_state) do
    GenServer.call(__MODULE__, {:write_store, db_state}, 60_000)
  end

  @impl GenServer
  def handle_cast(
        {:write_mutations, mutations, done_fn},
        %{async_store: %AsyncStore{} = async_store} = state
      ) do
    async_state = State.new(async_store)

    mutations
    |> Enum.reject(&is_nil/1)
    |> Enum.each(&Mutation.execute(&1, async_state))

    done_fn.()

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(
        {:write_store, db_state1},
        _from,
        %{async_store: %AsyncStore{} = async_store} = state
      ) do
    {top_keys, store} = WealthRank.prune_balance_ranking(async_store)

    db_state2 =
      store
      |> AsyncStore.mutations()
      |> Enum.reduce(db_state1, &Mutation.execute/2)

    AsyncStore.clear(async_store)

    _store = WealthRank.restore_ranking(async_store, top_keys)

    {:reply, db_state2, state}
  end
end
