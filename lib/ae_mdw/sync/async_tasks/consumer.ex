defmodule AeMdw.Sync.AsyncTasks.Consumer do
  @moduledoc """
  Database Sync tasks that run asynchronously consuming Model.AsyncTasks records.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Log

  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks.TaskSupervisor
  alias AeMdw.Sync.AsyncTasks.UpdateAex9Presence

  require Model
  require Logger

  import AeMdw.Util, only: [ok!: 1]

  @base_sleep_msecs 3_000
  @yield_timeout_msecs 100
  @task_timeout_msecs 20_000

  @type_mod %{
    update_aex9_presence: UpdateAex9Presence
  }

  # @max_retries 2
  # @backoff_msecs 10_000

  defmodule State do
    @type t :: %__MODULE__{}

    defstruct task: nil, m_task: nil, timer_ref: nil
  end

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok)
  end

  @impl GenServer
  def init(:ok) do
    schedule_demand()
    {:ok, %State{}}
  end

  @doc """
  Pull tasks from Producer.
  """
  @impl GenServer
  def handle_info(:demand, _state) do
    {:noreply, demand()}
  end

  @doc """
  Handle async task timeout.
  """
  def handle_info({:timedout, timeout_task}, %State{task: task, m_task: m_task}) do
    case timeout_task.ref == task.ref && Task.yield(task, @yield_timeout_msecs) do
      nil ->
        Task.shutdown(task, :brutal_kill)
        Producer.notify_timeout(m_task)

      _not_running ->
        :noop
    end

    {:noreply, demand()}
  end

  @doc """
  When the task finishes, demonitor and demands next task.
  """
  def handle_info({ref, :ok}, %State{task: current_task} = state) do
    Process.demonitor(ref, [:flush])

    if ref == current_task.ref or not is_nil(Task.yield(current_task, @yield_timeout_msecs)) do
      schedule_demand()
      {:noreply, %State{}}
    else
      # some still running
      {:noreply, state}
    end
  end

  @doc """
  Just acknowledge (ignore) the DOWN event.
  """
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %State{task: _task} = state) do
    {:noreply, state}
  end

  #
  # Used by consumers only
  #
  @spec run_supervised(Model.async_tasks_record(), boolean()) :: {Task.t(), term()}
  def run_supervised(m_task, is_long? \\ false) do
    task = Task.Supervisor.async_nolink(
      TaskSupervisor,
      fn ->
        :ok = process(m_task)
        set_done(m_task, is_long?)
      end
    )
    Log.info("[#{inspect(task.ref)}] #{inspect(m_task)}")

    timer_ref = if not is_long?, do: ok!(:timer.send_after(@task_timeout_msecs, {:timedout, task}))

    {task, timer_ref}
  end

  @spec process(Model.async_tasks_record()) :: :ok
  def process(Model.async_tasks(index: {_ts, type}, args: args)) do
    mod = @type_mod[type]
    apply(mod, :process, [args])
  end

  @spec set_done(Model.async_tasks_record(), boolean()) :: :ok
  def set_done(m_task, is_long?) do
    Model.async_tasks(index: index) = m_task
    Producer.notify_consumed(index, is_long?)
  end

  #
  # Private functions
  #
  @spec demand() :: State.t()
  defp demand() do
    m_task = Producer.dequeue()

    if nil != m_task do
      {task, timer_ref} = run_supervised(m_task)

      %State{
        task: task,
        m_task: m_task,
        timer_ref: timer_ref
      }
    else
      schedule_demand()
      %State{}
    end
  end

  defp schedule_demand() do
    sleep_msecs = @base_sleep_msecs + Enum.random(-200..200)
    Process.send_after(self(), :demand, sleep_msecs)
  end
end
