defmodule AeMdw.Sync.AsyncTasks.Consumer do
  @moduledoc """
  Database Sync tasks that run asynchronously consuming Model.AsyncTasks records.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Log

  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks.TaskSupervisor
  alias AeMdw.Sync.AsyncTasks.UpdateAex9State

  require Model
  require Logger

  @wait_msecs 1_000

  @type_mod %{
    update_aex9_state: UpdateAex9State
  }

  @type task_type() :: Model.async_task_type()

  defmodule State do
    @moduledoc """
    GenServer state
    """
    @type t :: %__MODULE__{}

    defstruct task: nil, m_task: nil
  end

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok)
  end

  @impl GenServer
  def init(:ok) do
    schedule_demand(@wait_msecs)
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
  When the task finishes, demonitor and demands next task.
  """
  def handle_info({ref, _ok_res}, _state) do
    Process.demonitor(ref, [:flush])

    schedule_demand()

    {:noreply, %State{}}
  end

  @doc """
  Rerun failed task or put it back to queue.
  """
  def handle_info(
        {:DOWN, ref, :process, _pid, _reason},
        %State{task: task, m_task: m_task} = state
      ) do
    schedule_demand()

    if ref == task.ref do
      new_task = run_supervised(m_task)
      {:noreply, %State{task: new_task, m_task: m_task}}
    else
      Producer.notify_error(m_task)
      {:noreply, state}
    end
  end

  #
  # Used by consumers only
  #
  @spec run_supervised(Model.async_task_record()) :: Task.t()
  def run_supervised(m_task) do
    task =
      Task.Supervisor.async_nolink(
        TaskSupervisor,
        fn ->
          :ok = process(m_task)
        end
      )

    Log.info("[#{inspect(task.ref)}] #{inspect(m_task)}")

    task
  end

  #
  # Private functions
  #
  @spec demand() :: State.t()
  defp demand() do
    m_task = Producer.dequeue()

    if nil != m_task do
      task = run_supervised(m_task)

      %State{
        task: task,
        m_task: m_task
      }
    else
      schedule_demand(@wait_msecs)
      %State{}
    end
  end

  @spec process(Model.async_task_record()) :: :ok
  defp process(Model.async_task(index: {_ts, type} = index, args: args, extra_args: extra_args)) do
    mod = @type_mod[type]
    done_fn = fn -> Producer.notify_consumed(index, args) end
    apply(mod, :process, [args ++ extra_args, done_fn])
    :ok
  end

  @spec schedule_demand(non_neg_integer()) :: :ok
  defp schedule_demand(sleep \\ 0) do
    Process.send_after(self(), :demand, sleep)
    :ok
  end
end
