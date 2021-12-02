defmodule AeMdw.Db.Sync.GenerationsLoader do
  use GenServer

  alias AeMdw.Db.Sync.Generation
  alias AeMdw.Db.Sync.GenerationsCache
  alias AeMdw.Log
  alias AeMdw.Node

  @max_load 300
  @max_load_per_turn 30
  @load_delay_msecs 5000

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(:ok) do
    {:ok, %{ranges: [], height_cached: -1}}
  end

  @doc """
  Adds a generation range to be loaded.
  """
  @spec load(Range.t()) :: :ok
  def load(first..last) when first > last do
    GenServer.cast(__MODULE__, {:add_load, last..first})
  end

  def load(first..last) do
    GenServer.cast(__MODULE__, {:add_load, first..last})
  end

  @doc """
  Sets a cache height to backpressure loading.
  """
  @spec notify_sync(Blocks.height()) :: :ok
  def notify_sync(height_cached) do
    GenServer.cast(__MODULE__, {:notify_sync, height_cached})
  end

  @impl GenServer
  def handle_cast({:add_load, first..last}, %{ranges: []} = state) do
    first
    |> do_load()
    |> GenerationsCache.add()

    if first == last do
      {:noreply, state}
    else
      new_state = %{state | ranges: [(first + 1)..last], height_cached: first}
      {:noreply, new_state, {:continue, :load}}
    end
  end

  @impl GenServer
  def handle_cast({:add_load, range}, %{ranges: ranges} = state) do
    {:noreply, %{state | ranges: ranges ++ [range]}}
  end

  @impl GenServer
  def handle_cast({:notify_sync, height_cached}, state) do
    {:noreply, %{state | height_cached: height_cached}}
  end

  @impl GenServer
  def handle_continue(:load, state) do
    do_load(state)
  end

  @impl GenServer
  def handle_info(:load, state) do
    do_load(state)
  end

  #
  # Private functions
  #
  defp do_load(%{ranges: [range | next_ranges], height_cached: height_cached} = state) do
    Log.info("load #{inspect([range | next_ranges])}")

    load_range = %Range{
      first: range.first,
      last: Enum.min([range.last, range.first + @max_load_per_turn])
    }

    if height_cached != -1 and load_range.last > height_cached + @max_load do
      Process.send_after(self(), :load, @load_delay_msecs)
      {:noreply, state}
    else
      Enum.each(load_range, fn height ->
        height
        |> do_load()
        |> GenerationsCache.add()
      end)

      new_state =
        if load_range.last == range.last do
          %{state | ranges: next_ranges}
        else
          next_range = %Range{first: load_range.last + 1, last: range.last}
          %{state | ranges: [next_range | next_ranges]}
        end

      if new_state.ranges == [] do
        {:noreply, new_state}
      else
        {:noreply, new_state, {:continue, :load}}
      end
    end
  end

  defp do_load(height) do
    {key_block, micro_blocks} = Node.Db.get_blocks(height)

    %Generation{
      height: height,
      key_block: key_block,
      micro_blocks: micro_blocks
    }
  end
end
