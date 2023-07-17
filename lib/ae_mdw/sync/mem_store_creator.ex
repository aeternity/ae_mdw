defmodule AeMdw.Sync.MemStoreCreator do
  @moduledoc """
  Process that creates MemStore state (process parent).
  """
  use GenServer

  alias AeMdw.Db.DbStore
  alias AeMdw.Db.MemStore

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  @spec init(:ok) :: {:ok, {nil, nil, []}}
  def init(:ok) do
    {:ok, {nil, nil, []}}
  end

  @spec create() :: MemStore.t()
  def create do
    GenServer.call(__MODULE__, :create)
  end

  @spec commit(MemStore.t()) :: :ok
  def commit(mem_store) do
    GenServer.cast(__MODULE__, {:commit, mem_store})
  end

  @impl true
  def handle_call(:create, _from, {endpoint_store, prev_endpoint_store, sync_stores}) do
    new_sync_store = MemStore.new(DbStore.new())
    sync_stores = [new_sync_store | sync_stores]
    {:reply, new_sync_store, {endpoint_store, prev_endpoint_store, sync_stores}}
  end

  @impl true
  def handle_cast({:commit, mem_store}, {endpoint_store, prev_endpoint_store, sync_stores}) do
    if prev_endpoint_store, do: MemStore.delete_store(prev_endpoint_store)

    Enum.each(sync_stores, fn store ->
      if store not in [mem_store, endpoint_store, prev_endpoint_store] do
        MemStore.delete_store(store)
      end
    end)

    {:noreply, {mem_store, endpoint_store, []}}
  end
end
