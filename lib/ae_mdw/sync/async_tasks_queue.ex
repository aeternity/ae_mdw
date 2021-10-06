defmodule AeMdw.Sync.AsyncTasksQueue do
  @moduledoc """
  Manages the queue for async tasks for Mdw database sychronization.
  """
  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Sync.TaskSupervisor

  require Ex2ms
  require Model

  @retry_delay_ms 3_000

  def start_link(_ars) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok, %{tasks: %{}}, {:continue, :process_backlog}}
  end

  def enqueue({request_type, args}) when is_atom(request_type) and is_list(args) do
    GenServer.call(__MODULE__, {request_type, args})
  end

  def handle_call(request, _from, state) do
    if is_enqueued?(request) do
      {:reply, :ok, state}
    else
      request_index = save(request)

      {:reply, :ok, run_async(request, request_index, state)}
    end
  end

  # Demonitor and pop if the task succeeds
  def handle_info({ref, _result}, state) do
    # The task succeed so we can cancel the monitoring and discard the DOWN message
    Process.demonitor(ref, [:flush])
    {_request_data, state} = pop_in(state.tasks[ref])

    {:noreply, state}
  end

  # Retry if the task fails
  def handle_info({:DOWN, ref, _, _, reason}, state) do
    {{request, request_index}, state} = pop_in(state.tasks[ref])
    IO.puts "#{inspect request} failed with reason #{inspect(reason)}"
    Process.send_after(__MODULE__, {:retry, request, request_index}, @retry_delay_ms)

    {:noreply, state}
  end

  # Handle retry after task failure
  def handle_info({:retry, request, request_index}, state) do
    {:noreply, run_async(request, request_index, state)}
  end

  def handle_continue(:process_backlog, state) do
    all_records_spec  = Ex2ms.fun do record -> record end

    Model.AsyncTasks
    |> Util.select(all_records_spec)
    |> Enum.each(fn {_rec_name, request_index, args} ->
      {request_type, _ts} = request_index
      request = {request_type, args}
      Process.send(__MODULE__, {:retry, request, request_index}, [:noconnect])
    end)

    {:noreply, state}
  end

  #
  # Private functions
  #
  defp save({request_type, args}) do
    :mnesia.sync_dirty(fn ->
      index = {request_type, System.system_time(:millisecond)}
      record = {Model.record(Model.AsyncTasks), index, args}
      :mnesia.write(Model.AsyncTasks, record, :write)
      index
    end)
  end

  defp is_enqueued?({request_type, args}) do
    exists_spec = Ex2ms.fun do
      {:_, {^request_type, :_}, ^args} -> true
    end

    [] != Util.select(Model.AsyncTasks, exists_spec)
  end

  defp run_async(request, request_index, state) do
    task = Task.Supervisor.async_nolink(TaskSupervisor, fn ->
      :poolboy.transaction(:async_tasks, fn pid ->
        # call worker
        GenServer.call(pid, request, 10_000)
        # dequeue task
        :mnesia.dirty_delete(Model.AsyncTasks, request_index)
      end)
    end)

    put_in(state.tasks[task.ref], {request, request_index})
  end
end
