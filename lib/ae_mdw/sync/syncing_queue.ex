defmodule AeMdw.Sync.SyncingQueue do
  @moduledoc """
  This queue appends all the tasks necessary for execution before the synchronization process
  begins.
  """

  alias AeMdw.Sync.Server, as: SyncServer
  alias Task.Supervisor, as: TaskSupervisor

  use GenServer

  @type task_fn :: (-> :ok)

  @spec start_link(term()) :: {:ok, pid()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec push(task_fn()) :: :ok
  def push(task_fn) do
    GenServer.call(__MODULE__, {:push, task_fn})
  end

  @spec enqueue(task_fn()) :: :ok
  def enqueue(task_fn) do
    GenServer.call(__MODULE__, {:enqueue, task_fn})
  end

  @impl true
  def init([]) do
    {:ok, {[], nil}}
  end

  @impl true
  def handle_call({:push, task_fn}, _from, {queue, task_ref}) do
    new_state =
      {[task_fn | queue], task_ref}
      |> check_process()

    {:reply, :ok, new_state}
  end

  def handle_call({:enqueue, task_fn}, _from, {queue, task_ref}) do
    new_state =
      {queue ++ [task_fn], task_ref}
      |> check_process()

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast(:complete, {[], _task_ref}), do: {:noreply, {[], nil}}

  def handle_cast(:complete, {queue, _task_ref}) do
    new_state =
      {queue, nil}
      |> check_process()

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  defp check_process({[task_fn | rest], nil}) do
    ref =
      TaskSupervisor.async_nolink(SyncServer.task_supervisor(), fn ->
        task_fn.()
        complete()
      end)

    {rest, ref}
  end

  defp check_process(state), do: state

  defp complete do
    GenServer.cast(__MODULE__, :complete)
  end
end
