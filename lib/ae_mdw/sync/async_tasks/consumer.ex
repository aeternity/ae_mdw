defmodule AeMdw.Sync.AsyncTasks.Consumer do
  @moduledoc """
  Database Sync tasks that run asynchronously consuming Model.AsyncTask records.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Log

  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks.TaskSupervisor
  alias AeMdw.Sync.AsyncTasks.UpdateAex9State
  alias AeMdw.Sync.AsyncTasks.UpdateTxStats
  alias AeMdw.Sync.AsyncTasks.StoreAccountBalance
  alias AeMdw.Sync.AsyncTasks.Migrate

  require Model
  require Logger

  @wait_msecs 1_000

  @type_mod %{
    update_aex9_state: UpdateAex9State,
    store_acc_balance: StoreAccountBalance,
    migrate: Migrate,
    update_tx_stats: UpdateTxStats
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
  Pull tasks from Producer and when the task finishes, demonitor and demands next task.

  If fails, rerun task or put it back to queue.
  """
  @impl GenServer
  def handle_info(:demand, _state) do
    {:noreply, demand()}
  end

  def handle_info({ref, _ok_res}, _state) do
    Process.demonitor(ref, [:flush])

    schedule_demand()

    {:noreply, %State{}}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, _reason},
        %State{task: task, m_task: m_task} = state
      ) do
    if task != nil and task.ref == ref do
      new_task = run_supervised(m_task)
      {:noreply, %State{task: new_task, m_task: m_task}}
    else
      schedule_demand()
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

    Log.info("[task_run] #{inspect(Model.async_task(m_task, :index))}")

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

    if mod == StoreAccountBalance do
      Logger.info("Skipping #{inspect(index)}")
      done_fn.()
    else
      mod.process(args ++ extra_args, done_fn)
    end

    :ok
  end

  @spec schedule_demand(non_neg_integer()) :: :ok
  defp schedule_demand(sleep \\ 0) do
    Process.send_after(self(), :demand, sleep)
    :ok
  end
end
