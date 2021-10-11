defmodule AeMdw.Sync.AsyncTasks.Producer do
  @moduledoc """
  Handles demand for sychronization async tasks.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Store

  require Model

  @typep task_index() :: {pos_integer(), atom()}

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(:ok) do
    Store.reset()
    {:ok, %{buffer: []}}
  end

  @spec enqueue(atom(), list()) :: :ok
  def enqueue(task_type, args) when is_atom(task_type) and is_list(args) do
    Store.save_new(task_type, args)
    :ok
  end

  @spec dequeue() :: nil | Model.async_tasks_record()
  def dequeue() do
    GenServer.call(__MODULE__, :dequeue)
  end

  @spec notify_consumed(task_index()) :: :ok
  def notify_consumed(task_index) do
    Store.set_done(task_index)
    :ok
  end

  @impl GenServer
  def handle_call(:dequeue, _from, state) do
    {m_task, new_state} = next_state(state)

    if nil != m_task do
      Model.async_tasks(index: index) = m_task
      Store.set_processing(index)
    end

    {:reply, m_task, new_state}
  end

  #
  # Private functions
  #
  defp next_state(%{buffer: []} = state) do
    case Store.fetch_unprocessed() do
      [] -> {nil, state}
      [m_task | buffer_tasks] -> {m_task, %{buffer: buffer_tasks}}
    end
  end

  defp next_state(%{buffer: [m_task | buffer_tasks]}) do
    {m_task, %{buffer: buffer_tasks}}
  end
end
