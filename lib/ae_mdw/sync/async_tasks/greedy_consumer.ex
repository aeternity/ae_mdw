defmodule AeMdw.Sync.AsyncTasks.GreedyConsumer do
  @moduledoc """
  Database Sync tasks that run in async and long running mode to consume Model.AsyncTasks records.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Log
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks.TaskSupervisor

  require Model
  require Logger

  @yield_timeout_msecs 100
  @long_timeout_msecs 60 * 60_000

  # @max_retries 2
  # @backoff_msecs 10_000

  defmodule State do
    defstruct queue: nil, task: nil, m_task: nil, timer_ref: nil
  end

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok)
  end

  @impl GenServer
  def init(:ok) do
    {:ok, %State{queue: :queue.new()}}
  end

  def enqueue(m_task) do
    GenServer.cast(__MODULE__, {:add, m_task})
  end

  @doc """
  Push new tasks to long running tasks queue.
  """
  @impl GenServer
  def handle_cast({:add, m_task}, %State{queue: queue, task: task} = state) do

    new_state =
      if is_nil(task) do
        m_task
        |> :queue.in(queue)
        |> handle_run()
      else
        state
      end

    {:noreply, new_state}
  end

  @doc """
  Check async task timeout.
  """
  @impl GenServer
  def handle_info({:check_timeout, task_ref}, %State{queue: queue, task: task, m_task: m_task}) do
    same_ref? = task_ref == task.ref

    result = if same_ref?, do: Task.yield(task, @yield_timeout_msecs) || :timeout

    if {:ok, :ok} == result, do: set_done(m_task)

    {:noreply, handle_run(queue)}
  end

  @doc """
  If the task succeeds, clean processing state and demands next task.
  """
  @impl GenServer
  def handle_info({ref, task_result}, %State{queue: queue, task: task, m_task: m_task}) do
    # The task succeed so we can cancel the monitoring
    Process.demonitor(ref, [:flush])
    Log.info("[#{inspect(task.ref)}] task_result: #{task_result}")

    if ref == task.ref and task_result == :ok, do: set_done(m_task)

    {:noreply, handle_run(queue)}
  end


  @doc """
  TODO: Retry max_retries times if the task fails.
  """
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %State{task: _task} = state) do
    # same_ref? = ref == task.ref
    # handle_result(same_ref?, reason, state)
    {:noreply, state}
  end

  #
  # Private functions
  #
  defp handle_run(queue1) do
    case :queue.out(queue1) do
      {{:value, m_task}, queue2} ->
        {task, timer_ref} = run_supervised(m_task)

        %State{
          queue: queue2,
          task: task,
          m_task: m_task,
          timer_ref: timer_ref
        }
      {:empty, _queue} ->
        %State{
          queue: queue1,
          task: nil,
          m_task: nil,
          timer_ref: nil
        }
    end
  end

  defp run_supervised(m_task) do
    task = Task.Supervisor.async_nolink(
      TaskSupervisor,
      fn ->
        process(m_task)
      end
    )
    Log.info("[#{inspect(task.ref)}] #{inspect(m_task)}")

    timer_ref = :timer.send_after(@long_timeout_msecs, :check_timeout)

    {task, timer_ref}
  end

  defp set_done(m_task) do
    Model.async_tasks(index: index) = m_task
    Producer.notify_consumed(index)
  end

  defp process(Model.async_tasks(index: {_ts, mod}, args: args)) do
    mod.process(args)
  end

  # defp test() do
  #   task = Task.Supervisor.async_nolink(MyTaskSupervisor, fn -> Process.sleep(90_000) end, shutdown: 10_000)
  #   receive do what -> IO.inspect what; after 30_000 -> IO.inspect :no_shutdown; end
  # end
end
