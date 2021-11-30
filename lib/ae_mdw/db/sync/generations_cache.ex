defmodule AeMdw.Db.Sync.GenerationsCache do
  @moduledoc """
  Cache of load AeMdw.Db.Sync.Generation(s).
  """
  use GenServer

  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Db.Sync.Generation

  @get_delay_msecs 150
  @get_timeout 60_000

  @typep generations() :: %{Blocks.height() => Generation.t()}
  @type microblocks_events() :: %{Blocks.block_index() => Contract.grouped_events()}

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  @spec init(:ok) ::
          {:ok, %{generations: generations(), mbs_events: microblocks_events()}}
  def init(:ok) do
    {:ok, %{generations: %{}, mbs_events: %{}}}
  end

  @spec add(Generation.t(), microblocks_events()) :: :ok
  def add(%Generation{} = generation, %{} = mbs_events_map) do
    GenServer.cast(__MODULE__, {:add, generation, mbs_events_map})
  end

  @spec get_generation(Blocks.height()) :: Generation.t()
  def get_generation(height) do
    GenServer.call(__MODULE__, {:get_generation, height}, @get_timeout)
  end

  @spec get_mb_events({Blocks.height(), Blocks.mbi()}) :: Contract.grouped_events()
  def get_mb_events({_height, _mbi} = block_index) do
    GenServer.call(__MODULE__, {:get_mb_events, block_index})
  end

  @impl GenServer
  def handle_cast({:add, generation, mbs_events_map}, %{
        generations: generations,
        mbs_events: mbs_events
      }) do
    new_state = %{
      generations: Map.put(generations, generation.height, generation),
      mbs_events: Map.merge(mbs_events, mbs_events_map)
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call({:get_generation, height}, caller, state) do
    {generation, state} = pop_in(state, [:generations, height])

    if is_nil(generation) do
      schedule_reply(caller, height)
      {:noreply, state}
    else
      {:reply, generation, state}
    end
  end

  @impl GenServer
  def handle_call({:get_mb_events, block_index}, _from, state) do
    {grouped_events, state} = pop_in(state, [:mbs_events, block_index])

    {:reply, grouped_events, state}
  end

  @impl GenServer
  def handle_info({:get_generation, caller, height}, state) do
    {generation, state} = pop_in(state, [:generations, height])

    if is_nil(generation) do
      schedule_reply(caller, height)
    else
      GenServer.reply(caller, generation)
    end

    {:noreply, state}
  end

  #
  # Private functions
  #
  defp schedule_reply(caller, height) do
    Process.send_after(self(), {:get_generation, caller, height}, @get_delay_msecs)
  end
end
