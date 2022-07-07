defmodule AeMdw.Sync.AsyncTasks.Consumer do
  @moduledoc """
  Database Sync tasks that run asynchronously consuming Model.AsyncTasks records.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Log

  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks.TaskSupervisor
  alias AeMdw.Sync.AsyncTasks.UpdateAex9State

  require Model
  require Logger

  import AeMdw.Util, only: [ok!: 1]

  @base_sleep_msecs 3_000
  @yield_timeout_msecs 100
  @task_timeout_msecs 40_000

  @type_mod %{
    update_aex9_state: UpdateAex9State
  }

  @type job_type() :: Model.async_task_type()

  # @max_retries 2
  # @backoff_msecs 10_000

  defmodule State do
    @moduledoc """
    GenServer state
    """
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
  def handle_info(:timeout, %State{task: task, m_task: m_task}) do
    case Task.yield(task, @yield_timeout_msecs) do
      nil ->
        Task.shutdown(task, :brutal_kill)
        Producer.notify_timeout(m_task)

      _not_running ->
        :noop
    end

    schedule_demand()

    {:noreply, %State{}}
  end

  @doc """
  When the task finishes, demonitor and demands next task.
  """
  def handle_info({ref, ok_res}, %State{task: current_task, timer_ref: timer_ref}) do
    Process.demonitor(ref, [:flush])

    if ok_res != :ok do
      Log.warn("Async task returned #{ok_res}, task=#{inspect(current_task)}")
    end

    if nil != timer_ref, do: :timer.cancel(timer_ref)

    schedule_demand()

    {:noreply, %State{}}
  end

  @doc """
  Just acknowledge (ignore) the DOWN event.
  """
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %State{} = state) do
    {:noreply, state}
  end

  #
  # Used by consumers only
  #
  @spec run_supervised(Model.async_task_record(), boolean()) ::
          {Task.t(), :timer.tref() | nil}
  def run_supervised(m_task, is_long? \\ false) do
    task =
      Task.Supervisor.async_nolink(
        TaskSupervisor,
        fn ->
          :ok = process(m_task)
          set_done(m_task, is_long?)
        end
      )

    Log.info("[#{inspect(task.ref)}] #{inspect(m_task)}")

    timer_ref = if not is_long?, do: ok!(:timer.send_after(@task_timeout_msecs, :timeout))

    {task, timer_ref}
  end

  @spec mutations(Model.async_task_type(), Model.async_task_args()) :: [Mutation.t()]
  def mutations(task_type, args) do
    mod = @type_mod[task_type]
    apply(mod, :mutations, [args])
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

  @spec process(Model.async_task_record()) :: :ok
  defp process(Model.async_task(index: {_ts, type}, args: args, extra_args: extra_args)) do
    mod = @type_mod[type]
    apply(mod, :process, [args ++ extra_args])
    :ok
  end

  @spec set_done(Model.async_task_record(), boolean()) :: :ok
  defp set_done(Model.async_task(index: index, args: args), is_long?) do
    Producer.notify_consumed(index, args, is_long?)
  end

  @spec schedule_demand() :: :ok
  defp schedule_demand() do
    sleep_msecs = @base_sleep_msecs + Enum.random(-200..200)
    Process.send_after(self(), :demand, sleep_msecs)
    :ok
  end
end
