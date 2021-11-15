defmodule AeMdw.Sync.AsyncTasks.LongTaskConsumer do
  @moduledoc """
  Database Sync tasks that run in async and long running mode to consume Model.AsyncTasks records.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Log
  alias AeMdw.Sync.AsyncTasks.Consumer

  require Model
  require Logger

  @yield_timeout_msecs 100

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
    {:noreply, %{state | queue: :queue.in(m_task, queue)}}
  end

  @doc """
  Check async task timeout.
  """
  @impl GenServer
  def handle_info({:timedout, task_ref}, %State{queue: queue, task: task}) do
    if task_ref == task.ref do
      Task.yield(task, @yield_timeout_msecs) || Task.shutdown(task)
    end

    {:noreply, run_next(queue)}
  end

  @doc """
  If the task succeeds, clean processing state and runs next task.
  """
  @impl GenServer
  def handle_info({ref, task_result}, %State{queue: queue, task: task}) do
    # The task succeed so we can cancel the monitoring
    Process.demonitor(ref, [:flush])
    Log.info("[#{inspect(task.ref)}] task_result: #{task_result}")

    {:noreply, run_next(queue)}
  end


  @doc """
  Just acknowledge (ignore) the DOWN event.
  """
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %State{task: _task} = state) do
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
end
