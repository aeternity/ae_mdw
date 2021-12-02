defmodule AeMdw.Db.Sync.GenerationsCache do
  @moduledoc """
  Cache of loaded AeMdw.Db.Sync.Generation(s)
  and runs async tasks to load microblock contract events.
  """
  use GenServer

  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Db.Sync.Generation
  alias AeMdw.Db.Sync.EventsTasksSupervisor

  @get_timeout 60_000
  @get_events_timeout 10 * 60_000
  @get_delay_msecs 150

  @yield_timeout_msecs 100
  @max_events_tasks 2

  @typep generations() :: %{Blocks.height() => Generation.t()}
  @type microblocks_events() :: %{Blocks.block_index() => Contract.grouped_events()}

  @doc """
  Starts a single blocks consumer.
  """
  @spec start_link([]) :: GenServer.on_start()
  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  The state is comprised of:
  - generations: map of height to generation blocks
  - pending_mbs: a set of microblock indexes with pending contract events to run
  - tasks: map of task reference to running contract events task
  - mbs_events: map of microblock index to contract events
  """
  @impl GenServer
  @spec init(:ok) ::
          {:ok,
           %{
             generations: generations(),
             pending_mbs: MapSet.t(),
             tasks: %{reference() => Task.t()},
             mbs_events: microblocks_events()
           }}
  def init(:ok) do
    {:ok, %{generations: %{}, pending_mbs: MapSet.new(), tasks: %{}, mbs_events: %{}}}
  end

  #
  # Client
  #

  @doc """
  Add produced generation blocks.
  """
  @spec add(Generation.t()) :: :ok
  def add(%Generation{} = generation) do
    GenServer.cast(__MODULE__, {:add, generation})
  end

  @doc """
  Gets key and micro blocks of a generation.
  """
  @spec get_generation(Blocks.height()) :: Generation.t()
  def get_generation(height) do
    GenServer.call(__MODULE__, {:get_generation, height}, @get_timeout)
  end

  @doc """
  Consumes contract events of a micro block.
  """
  @spec get_mb_events({Blocks.height(), Blocks.mbi()}) :: Contract.grouped_events()
  def get_mb_events({_height, _mbi} = block_index) do
    GenServer.call(__MODULE__, {:get_mb_events, block_index}, @get_events_timeout)
  end

  #
  # Server
  #

  @doc """
  Adds produced generation blocks.
  """
  @impl GenServer
  def handle_cast({:add, generation}, state) do
    new_state =
      state
      |> put_in([:generations, generation.height], generation)
      |> add_events_tasks(generation.height)

    {:noreply, new_state}
  end

  @doc """
  Gets generation blocks if available otherwise schedule reply.
  """
  @impl GenServer
  def handle_call({:get_generation, height}, caller, state) do
    {generation, state} = maybe_pop_generation(state, height)

    if is_nil(generation) do
      schedule_reply({:get_generation, caller, height})
      {:noreply, state}
    else
      {:reply, generation, state}
    end
  end

  @doc """
  Consumes contract events if available otherwise schedule reply.
  """
  @impl GenServer
  def handle_call({:get_mb_events, block_index}, caller, state) do
    {grouped_events, state} = pop_in(state, [:mbs_events, block_index])

    if is_nil(grouped_events) do
      schedule_reply({:get_mb_events, caller, block_index})
      {:noreply, state}
    else
      {:reply, grouped_events, state}
    end
  end

  @doc """
  Gets generation after reescheduling.
  """
  @impl GenServer
  def handle_info({:get_generation, caller, height} = request, state) do
    {generation, state} = maybe_pop_generation(state, height)

    if is_nil(generation) do
      schedule_reply(request)
    else
      GenServer.reply(caller, generation)
    end

    {:noreply, state}
  end

  @doc """
  Consumes contract events after reescheduling.
  """
  @impl GenServer
  def handle_info({:get_mb_events, caller, block_index} = request, state) do
    {grouped_events, state} = pop_in(state, [:mbs_events, block_index])

    new_state =
      if is_nil(grouped_events) do
        schedule_reply(request)

        state
      else
        GenServer.reply(caller, grouped_events)

        cleanup_generation(state, block_index)
      end

    {:noreply, new_state}
  end

  @doc """
  Handles contract events task result.
  """
  @impl GenServer
  def handle_info({ref, {block_index, mb_events}}, state) do
    Process.demonitor(ref, [:flush])

    new_state =
      state
      |> handle_task_finished(ref, block_index, mb_events)
      |> run_next_events_task()

    {:noreply, new_state}
  end

  @doc """
  Just acknowledge/ignore the DOWN message when reason is success.
  """
  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  #
  # Private functions
  #
  # Runs ad-hoc events task or add it to pending set.
  defp add_events_tasks(state, height) do
    %{micro_blocks: micro_blocks} = Map.get(state.generations, height)

    updated_state =
      state
      |> yield_tasks()
      |> run_next_events_task()

    micro_blocks
    |> Enum.with_index()
    |> Enum.reduce(updated_state, fn {mblock, mbi},
                                     %{pending_mbs: pending_mbs, tasks: tasks} = new_state ->
      block_index = {height, mbi}

      if map_size(tasks) < @max_events_tasks do
        run_task(new_state, mblock, block_index)
      else
        %{new_state | pending_mbs: MapSet.put(pending_mbs, block_index)}
      end
    end)
  end

  # Runs next task from pending set
  defp run_next_events_task(%{generations: generations, pending_mbs: pending_mbs} = state) do
    pending_mbs
    |> MapSet.to_list()
    |> Enum.sort()
    |> List.first()
    |> case do
      nil ->
        state

      {height, next_mbi} = block_index ->
        %{micro_blocks: micro_blocks} = Map.get(generations, height)

        mblock = find_micro_block(micro_blocks, next_mbi)

        run_task(state, mblock, block_index)
    end
  end

  # Gets a microblock by index
  defp find_micro_block(micro_blocks, next_mbi) do
    micro_blocks
    |> Enum.with_index()
    |> Enum.find_value(fn {mblock, mbi} -> if mbi == next_mbi, do: mblock end)
  end

  # Runs an event task and check if executes quickly
  defp run_task(state, nil, _block_index), do: state

  defp run_task(state, mblock, block_index) do
    task =
      Task.Supervisor.async_nolink(
        EventsTasksSupervisor,
        fn ->
          events = AeMdw.Contract.get_grouped_events(mblock)
          {block_index, events}
        end
      )

    state
    |> put_in([:tasks, task.ref], task)
    |> update_in([:pending_mbs], fn pending_mbs -> MapSet.delete(pending_mbs, block_index) end)
    |> yield_task(task.ref)
  end

  # Checks task result and update tasks execution state
  defp yield_tasks(%{tasks: tasks} = state) do
    tasks
    |> Map.keys()
    |> Enum.reduce(state, fn task_ref, new_state ->
      yield_task(new_state, task_ref)
    end)
  end

  defp yield_task(%{tasks: tasks} = state, task_ref) do
    task = Map.get(tasks, task_ref)

    case Task.yield(task, @yield_timeout_msecs) do
      nil ->
        state

      {:ok, {block_index, mb_events}} ->
        handle_task_finished(state, task_ref, block_index, mb_events)
    end
  end

  defp handle_task_finished(state, task_ref, block_index, mb_events) do
    {_task, new_state} =
      state
      |> put_in([:mbs_events, block_index], mb_events)
      |> pop_in([:tasks, task_ref])

    new_state
  end

  # Gets generation blocks and consumes it only on last mbi read (txs needed for microblocks events tasks)
  defp maybe_pop_generation(%{generations: generations} = state, height) do
    generation = Map.get(generations, height)

    if not is_nil(generation) and generation.micro_blocks == [] do
      pop_in(state, [:generations, height])
    else
      {generation, state}
    end
  end

  # Deletes a generation if the microblock index is the last one (fully consumed)
  defp cleanup_generation(%{generations: generations} = state, {height, mbi}) do
    generation = Map.get(generations, height)

    if length(generation.micro_blocks) - 1 == mbi do
      %{state | generations: Map.delete(generations, height)}
    else
      state
    end
  end

  # Schedules to read the state again
  defp schedule_reply(request) do
    Process.send_after(self(), request, @get_delay_msecs)
  end
end
