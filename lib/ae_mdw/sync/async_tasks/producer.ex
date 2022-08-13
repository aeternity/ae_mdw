defmodule AeMdw.Sync.AsyncTasks.Producer do
  @moduledoc """
  Handles demand for sychronization async tasks.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks.Store
  alias AeMdw.Sync.AsyncTasks.Stats

  require Model
  require Logger

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(:ok) do
    Store.reset()
    {:ok, %{dequeue_buffer: []}}
  end

  @spec enqueue(atom(), list(), list(), only_new: boolean()) :: :ok
  def enqueue(task_type, dedup_args, extra_args, only_new: only_new) do
    task_index = {System.system_time(), task_type}
    m_task = Model.async_task(index: task_index, args: dedup_args, extra_args: extra_args)

    :ok = Store.add(m_task, only_new: only_new)
  end

  @spec save_enqueued() :: :ok
  def save_enqueued() do
    Store.save()
  end

  @spec dequeue() :: nil | Model.async_task_record()
  def dequeue() do
    m_task = Store.next_unprocessed()

    if m_task do
      Store.count_unprocessed()
      |> Stats.update_buffer_len()
    end

    m_task
  end

  @spec notify_consumed(Model.async_task_index(), Model.async_task_args()) :: :ok
  def notify_consumed(task_index, task_args) do
    Store.set_done(task_index, task_args)
    Stats.update_consumed()

    :ok
  end
end
