defmodule AeMdw.Sync.MemStoreCreator do
  @moduledoc """
  Process that creates MemStore state (process parent).
  """
  use GenServer

  alias AeMdw.Db.DbStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Store

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  @spec init(:ok) :: {:ok, []}
  def init(:ok) do
    {:ok, []}
  end

  @spec create() :: MemStore.t()
  def create do
    GenServer.call(__MODULE__, :create)
  end

  @spec delete(Store.t()) :: :ok
  def delete(mem_store) do
    GenServer.cast(__MODULE__, {:delete, mem_store})
  end

  @impl true
  def handle_call(:create, _from, list) do
    new_store = MemStore.new(DbStore.new())
    {:reply, new_store, [new_store | list]}
  end

  @impl true
  def handle_cast({:delete, store}, list) do
    MemStore.delete_store(store)
    {:noreply, list -- [store]}
  end
end
