defmodule AeMdw.Sync.AsyncTasks.LongTaskConsumer do
  @moduledoc """
  Database Sync tasks that run in async and long running mode to consume Model.AsyncTasks records.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Consumer

  require Model

  @sleep_msecs 60_000

  # @max_retries 2
  # @backoff_msecs 10_000

  defmodule State do
    defstruct queue: nil, task: nil, timer_ref: nil
  end

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(:ok) do
    {:ok, %State{queue: :queue.new()}}
  end

  def enqueue(m_task) do
    GenServer.cast(__MODULE__, {:enqueue, m_task})
  end

  @doc """
  Push new tasks to long running tasks queue.
  """
  @impl GenServer
  def handle_cast({:enqueue, m_task}, %State{queue: queue} = state) do
    new_queue = :queue.in(m_task, queue)

    if :queue.is_empty(queue) do
      {:noreply, run_next(new_queue)}
    else
      {:noreply, %{state | queue: new_queue}}
    end
  end

  @impl GenServer
  def handle_info(:next, %State{queue: queue}) do
    {:noreply, run_next(queue)}
  end

  @doc """
  If the task succeeds, only demonitor.
  """
  @impl GenServer
  def handle_info({ref, :ok}, state) do
    Process.demonitor(ref, [:flush])

    {:noreply, state}
  end

  @doc """
  DOWN event is always received, so schedule next (no evidence for a need to retry).
  """
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    schedule_next()
    {:noreply, state}
  end

  #
  # Private functions
  #
  defp run_next(queue1) do
    case :queue.out(queue1) do
      {{:value, m_task}, queue2} ->
        {task, timer_ref} = Consumer.run_supervised(m_task, true)

        %State{
          queue: queue2,
          task: task,
          timer_ref: timer_ref
        }
      {:empty, _queue} ->
        %State{
          queue: queue1,
          task: nil,
          timer_ref: nil
        }
    end
  end

  defp schedule_next() do
    Process.send_after(self(), :next, @sleep_msecs)
  end
end
