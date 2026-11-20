defmodule AeMdw.Sync.MemStoreCreator do
  @moduledoc """
  Process that creates MemStore state (process parent).

  On each commit, stores that are no longer in use are retired, and they're deleted
  once they have been retired for `:memstore_lifetime_secs`.
  """
  use GenServer

  alias AeMdw.Db.DbStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.State

  @typep seconds() :: integer()
  @typep entry() :: %{store: MemStore.t(), retired_at: seconds() | nil}

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  @spec init(:ok) :: {:ok, [entry()]}
  def init(:ok), do: {:ok, []}

  @spec create() :: MemStore.t()
  def create do
    GenServer.call(__MODULE__, {:create, DbStore.new()})
  end

  @spec create(fallback_store :: AeMdw.Db.Store.t()) :: MemStore.t()
  def create(fallback_store) do
    GenServer.call(__MODULE__, {:create, fallback_store})
  end

  @spec commit(MemStore.t()) :: :ok
  def commit(mem_store) do
    GenServer.cast(__MODULE__, {:commit, mem_store})
  end

  @impl true
  def handle_call({:create, fallback_store}, _from, stores) do
    sync_store = MemStore.new(fallback_store)

    {:reply, sync_store, [%{store: sync_store, retired_at: nil} | stores]}
  end

  # Only a commit retires stores: mem syncs run one at a time and commit when they end,
  # so no other store is still syncing then.
  @impl true
  def handle_cast({:commit, mem_store}, stores) do
    now = now()
    in_use = [mem_store | in_use_stores(stores)]

    {stores, retired?} =
      Enum.map_reduce(stores, false, fn
        %{store: store, retired_at: nil} = entry, retired? ->
          if store in in_use, do: {entry, retired?}, else: {%{entry | retired_at: now}, true}

        entry, retired? ->
          {entry, retired?}
      end)

    if retired? do
      _ref = Process.send_after(self(), :sweep, (lifetime_secs() + 1) * 1_000)
      :ok
    end

    {:noreply, delete_expired(stores, in_use, now)}
  end

  @impl true
  def handle_info(:sweep, stores),
    do: {:noreply, delete_expired(stores, in_use_stores(stores), now())}

  def handle_info(_msg, stores), do: {:noreply, stores}

  # Endpoints may read a retired store for `:memstore_lifetime_secs`. A retired store in
  # use again is kept, and the next commit that finds it unused retires it anew.
  defp delete_expired(stores, in_use, now) do
    lifetime_secs = lifetime_secs()

    Enum.flat_map(stores, fn
      %{retired_at: nil} = entry ->
        [entry]

      %{store: store, retired_at: retired_at} = entry ->
        cond do
          store in in_use ->
            [%{entry | retired_at: nil}]

          now - retired_at > lifetime_secs ->
            MemStore.delete_store(store)
            []

          true ->
            [entry]
        end
    end)
  end

  # The newest store may still be syncing, and endpoints read the global one.
  defp in_use_stores(stores) do
    newest =
      case stores do
        [%{store: store} | _older] -> store
        [] -> nil
      end

    [newest, State.current_mem_store()]
  end

  defp now, do: System.monotonic_time(:second)

  # Some legacy V1 endpoints might fetch transaction data from multiple blocks.
  # `:memstore_lifetime_secs` config allows endpoints to use past mem stores until it's expiration
  defp lifetime_secs do
    case :persistent_term.get({__MODULE__, :memstore_lifetime_secs}, nil) do
      nil ->
        lifetime_secs = Application.fetch_env!(:ae_mdw, :memstore_lifetime_secs)
        :persistent_term.put({__MODULE__, :memstore_lifetime_secs}, lifetime_secs)
        lifetime_secs

      lifetime_secs ->
        lifetime_secs
    end
  end
end
