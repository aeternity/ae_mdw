defmodule AeMdw.Sync.AsyncTasks.Producer do
  @moduledoc """
  Handles demand for sychronization async tasks.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Log
  alias AeMdw.Sync.AsyncTasks.LongTaskConsumer
  alias AeMdw.Sync.AsyncTasks.Store
  alias AeMdw.Sync.AsyncTasks.Stats

  require Model
  require Logger

  @max_buffer_size 100

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(:ok) do
    Store.reset()
    {:ok, %{enqueue_buffer: [], dequeue_buffer: []}}
  end

  @spec enqueue(atom(), list()) :: :ok
  def enqueue(task_type, args) when is_atom(task_type) and is_list(args) do
    GenServer.cast(__MODULE__, {:enqueue, task_type, args})
  end

  @spec commit_enqueued() :: :ok
  def commit_enqueued() do
    GenServer.cast(__MODULE__, :commit_enqueued)
  end

  @spec dequeue() :: nil | Model.async_tasks_record()
  def dequeue() do
    GenServer.call(__MODULE__, :dequeue)
  end

  @spec notify_consumed(Store.task_index(), Store.task_args(), boolean()) :: :ok
  def notify_consumed(task_index, task_args, is_long?) do
    Store.set_done(task_index, task_args)
    Stats.update_consumed(is_long?)

    if is_long?, do: Log.info("Long task finished: #{inspect(task_index)}")

    :ok
  end

  @spec notify_timeout(Model.async_tasks_record()) :: :ok
  def notify_timeout(m_task) do
    Log.warn("Long task enqueued: #{inspect(m_task)}")
    LongTaskConsumer.enqueue(m_task)
    Stats.inc_long_tasks_count()

    :ok
  end

  @impl GenServer
  def handle_cast({:enqueue, task_type, args}, %{enqueue_buffer: enqueue_buffer} = state) do
    {:noreply, %{state | enqueue_buffer: [{task_type, args} | enqueue_buffer]}}
  end

  @impl GenServer
  def handle_cast(:commit_enqueued, %{enqueue_buffer: []} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:commit_enqueued, %{enqueue_buffer: enqueue_buffer} = state) do
    enqueue_buffer
    |> Enum.reverse()
    |> Enum.each(fn {task_type, args} -> Store.save_new(task_type, args) end)

    {:noreply, %{state | enqueue_buffer: []}}
  end

  @impl GenServer
  def handle_call(:dequeue, _from, state) do
    {m_task, %{dequeue_buffer: new_buffer} = new_state} = next_state(state)

    if nil != m_task do
      Model.async_tasks(index: index) = m_task
      Store.set_processing(index)
    end

    new_buffer
    |> length()
    |> Stats.update_buffer_len(@max_buffer_size)

    {:reply, m_task, new_state}
  end

  #
  # Private functions
  #
  defp next_state(%{dequeue_buffer: []} = state) do
    case Store.fetch_unprocessed(@max_buffer_size) do
      [] -> {nil, state}
      [m_task | buffer_tasks] -> {m_task, %{state | dequeue_buffer: buffer_tasks}}
    end
  end

  defp next_state(%{dequeue_buffer: [m_task | buffer_tasks]} = state) do
    {m_task, %{state | dequeue_buffer: buffer_tasks}}
  end
end
