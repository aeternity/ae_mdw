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

  alias AeMdw.Database
  alias AeMdw.Log
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.State
  alias AeMdw.Db.TxnDbStore

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec init(:ok) :: {:ok, %{last_db_kbi: AeMdw.Blocks.height()}}
  @impl GenServer
  def init(:ok) do
    {:ok, %{last_db_kbi: 0}}
  end

  @spec write_mutations(AeMdw.Blocks.block_index(), [Mutation.t()], fun()) :: :ok
  def write_mutations(block_index, async_mutations, done_fn) do
    GenServer.cast(__MODULE__, {:write_mutations, block_index, async_mutations, done_fn})
  end

  @spec write_async_store(State.t()) :: State.t()
  def write_async_store(db_state) do
    GenServer.call(__MODULE__, {:write_store, db_state})
  end

  @impl GenServer
  def handle_cast(
        {:write_mutations, {kbi, _mbi} = block_index, mutations, done_fn},
        %{last_db_kbi: last_db_kbi} = state
      ) do
    if Database.exists?(Model.Block, block_index) || kbi <= last_db_kbi do
      state = State.new(TxnDbStore.new())

      %{store: store} =
        mutations
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(state, &Mutation.execute/2)

      with {:error, reason} <- TxnDbStore.commit(store) do
        {:ok, error_msg} = Log.commit_error(reason, mutations)
        raise error_msg
      end
    else
      async_state = State.new(AsyncStore.instance())

      mutations
      |> Enum.reject(&is_nil/1)
      |> Enum.each(&Mutation.execute(&1, async_state))
    end

    done_fn.()

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:write_store, db_state}, _from, _state) do
    new_state =
      AsyncStore.instance()
      |> AsyncStore.mutations()
      |> Enum.reduce(db_state, &Mutation.execute/2)

    AsyncStore.clear(AsyncStore.instance())

    {:reply, new_state, %{last_db_kbi: last_db_kbi(db_state)}}
  end

  defp last_db_kbi(db_state) do
    case State.prev(db_state, Model.Block, {nil, nil}) do
      {:ok, {kbi, mbi}} ->
        if mbi == -1 do
          {:ok, {kbi, _mbi}} = State.prev(db_state, Model.Block, {kbi, mbi})
          kbi
        else
          kbi
        end

      :none ->
        0
    end
  end
end
