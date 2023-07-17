defmodule AeMdw.Sync.MemStoreCreator do
  @moduledoc """
  Process that creates MemStore state (process parent).
  """
  use GenServer

  alias AeMdw.Db.DbStore
  alias AeMdw.Db.MemStore

  @max_mem_sync_secs Application.compile_env!(:ae_mdw, :max_mem_sync_secs)

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

  @impl true
  def handle_call(:create, _from, prev_stores) do
    {old_stores, new_ones} =
      Enum.split_with(prev_stores, fn %{time: time} ->
        System.monotonic_time(:second) - time > @max_mem_sync_secs
      end)

    Enum.each(old_stores, &MemStore.delete_store(&1.store))

    new_store = MemStore.new(DbStore.new())

    {:reply, new_store, [%{store: new_store, time: System.monotonic_time(:second)} | new_ones]}
  end
end
