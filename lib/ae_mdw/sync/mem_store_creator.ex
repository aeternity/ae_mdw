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
  @spec init(:ok) :: {:ok, %{commited: nil, stores: []}}
  def init(:ok) do
    {:ok, %{commited: nil, stores: []}}
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
  def handle_call(:create, _from, %{stores: stores} = state) do
    sync_store = MemStore.new(DbStore.new())
    created_at = System.monotonic_time(:second)
    stores = [%{store: sync_store, created_at: created_at} | stores]

    {:reply, sync_store, %{state | stores: stores}}
  end

  @impl true
  def handle_cast({:commit, mem_store}, %{commited: endpoint_store, stores: stores}) do
    now = System.monotonic_time(:second)

    {keep_stores, expired_stores} =
      Enum.split_with(stores, fn %{store: store, created_at: created_at} ->
        store in [mem_store, endpoint_store] or not expired?(now - created_at)
      end)

    Enum.each(expired_stores, fn %{store: store} -> MemStore.delete_store(store) end)

    {:noreply, %{commited: mem_store, stores: keep_stores}}
  end

  # Some legacy V1 endpoints might fetch transaction data from multiple blocks.
  # `:memstore_lifetime_secs` config allows endpoints to use past mem stores until it's expiration
  defp expired?(elapsed_time) do
    case :persistent_term.get({__MODULE__, :memstore_lifetime_secs}, nil) do
      nil ->
        lifetime_secs = Application.fetch_env!(:ae_mdw, :memstore_lifetime_secs)
        :persistent_term.put({__MODULE__, :memstore_lifetime_secs}, lifetime_secs)
        elapsed_time > lifetime_secs

      lifetime_secs ->
        elapsed_time > lifetime_secs
    end
  end
end
