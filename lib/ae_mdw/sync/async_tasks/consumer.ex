defmodule AeMdw.Sync.AsyncTasks.Consumer do
  @moduledoc """
  Database Sync tasks that run asynchronously consuming Model.AsyncTasks records.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Log

  alias AeMdw.Sync.AsyncTasks.GreedyConsumer
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks.TaskSupervisor

  require Model
  require Logger

  @type yield_result :: {:ok, :ok} | {:ok, :error} | {:exit, term()} | :timeout

  @base_sleep_msecs 700

  @yield_timeout_msecs 100
  @task_timeout_msecs 60_000

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
  Check async task timeout.
  """
  @impl GenServer
  def handle_info({:check_timeout, task_ref}, %State{task: task} = state) do
    same_ref? = task_ref == task.ref

    result = if same_ref?, do: Task.yield(task, @yield_timeout_msecs) || :timeout

    {:noreply, handle_result(same_ref?, result, state)}
  end

  @doc """
  If the task succeeds, clean processing state and demands next task.
  """
  @impl GenServer
  def handle_info({ref, task_result}, %State{task: task, m_task: m_task}) do
    # The task succeed so we can cancel the monitoring
    Process.demonitor(ref, [:flush])
    Log.info("task_result: #{task_result}")

    new_state =
      if ref == task.ref do
        case task_result do
          :ok ->
            set_done(m_task)
            demand()

          _error ->
            # TODO: retry
            %State{}
        end
      else
        %State{}
      end

    {:noreply, new_state}
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
  @spec demand() :: State.t()
  defp demand() do
    m_task = Producer.dequeue()

    if nil != m_task do
      run_supervised(m_task)
    else
      schedule_demand()
      %State{}
    end
  end

  @spec run_supervised(Model.async_tasks_record()) :: State.t()
  defp run_supervised(m_task) do
    task = Task.Supervisor.async_nolink(
      TaskSupervisor,
      fn ->
        process(m_task)
      end
    )
    Log.info("[#{inspect(task.ref)}] #{inspect(m_task)}")

    timer_ref = :timer.send_after(@task_timeout_msecs, :check_timeout)

    %State{
      task: task,
      m_task: m_task,
      timer_ref: timer_ref
    }
  end

  @spec handle_result(same_ref? :: boolean(), yield_result :: yield_result(), state :: State.t()) :: State.t()
  defp handle_result(true = _same_ref?, {:ok, :ok} = _task_res, state) do
    set_done(state.m_task)
    %State{}
  end

  # timeout
  defp handle_result(true = _same_ref?, :timeout, %State{m_task: m_task}) do
    GreedyConsumer.enqueue(m_task)
    %State{}
  end

  # no retries for now
  defp handle_result(true, _any_res, state), do: state

  # ignore old task ref
  defp handle_result(false, _any_res, state), do: state

  defp set_done(m_task) do
    Model.async_tasks(index: index) = m_task
    Producer.notify_consumed(index)
  end

  defp process(Model.async_tasks(index: {_ts, mod}, args: args)) do
    mod.process(args)
  end

  defp schedule_demand() do
    sleep_msecs = @base_sleep_msecs + Enum.random(-200..200)
    Process.send_after(self(), :demand, sleep_msecs)
  end
end
