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
  @typep state() :: %{commited: MemStore.t() | nil, stores: [entry()]}

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  @spec init(:ok) :: {:ok, state()}
  def init(:ok) do
    {:ok, %{commited: nil, stores: []}}
  end

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
  def handle_call({:create, fallback_store}, _from, %{stores: stores} = state) do
    sync_store = MemStore.new(fallback_store)
    entry = %{store: sync_store, retired_at: nil}

    {:reply, sync_store, %{state | stores: [entry | stores]}}
  end

  @impl true
  def handle_cast({:commit, mem_store}, %{commited: prev_commited, stores: stores} = state) do
    now = now()
    in_use = [prev_commited | in_use_stores(mem_store, stores)]

    {stores, retired_count} =
      Enum.map_reduce(stores, 0, fn %{store: store, retired_at: retired_at} = entry, count ->
        cond do
          store in in_use -> {%{entry | retired_at: nil}, count}
          retired_at == nil -> {%{entry | retired_at: now}, count + 1}
          true -> {entry, count}
        end
      end)

    if retired_count > 0 do
      _ref = Process.send_after(self(), :sweep, (lifetime_secs() + 1) * 1_000)
      :ok
    end

    {:noreply, delete_expired(%{state | commited: mem_store, stores: stores}, now)}
  end

  @impl true
  def handle_info(:sweep, state), do: {:noreply, delete_expired(state, now())}

  # Endpoints may still read a retired store until `:memstore_lifetime_secs` after it
  # was retired. The committed, newest and global stores are never deleted.
  defp delete_expired(%{commited: commited, stores: stores} = state, now) do
    in_use = in_use_stores(commited, stores)
    lifetime_secs = lifetime_secs()

    {expired, keep} =
      Enum.split_with(stores, fn %{store: store, retired_at: retired_at} ->
        retired_at != nil and now - retired_at > lifetime_secs and store not in in_use
      end)

    Enum.each(expired, fn %{store: store} -> MemStore.delete_store(store) end)

    %{state | stores: keep}
  end

  defp in_use_stores(commited, stores) do
    newest =
      case stores do
        [%{store: store} | _older] -> store
        [] -> nil
      end

    [commited, newest, State.current_mem_store()]
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
