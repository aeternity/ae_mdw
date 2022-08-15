defmodule AeMdw.AsyncTaskTestUtil do
  @moduledoc """
  Test helper functions to synchronize with Async Tasks results
  """

  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Db.Model

  require Model

  @spec wakeup_consumers() :: :ok
  def wakeup_consumers do
    AsyncTasks.Supervisor.start_link([])
    Process.sleep(100)

    AsyncTasks.Supervisor
    |> Supervisor.which_children()
    |> Enum.filter(fn {id, _pid, _type, _mod} ->
      is_binary(id) and String.starts_with?(id, "Elixir.AeMdw.Sync.AsyncTasks.Consumer")
    end)
    |> Enum.each(fn {_id, consumer_pid, _type, _mod} ->
      Process.send(consumer_pid, :demand, [:noconnect])
    end)
  end

  @spec list_pending() :: [Model.async_task_record()]
  def list_pending do
    :async_tasks_pending
    |> :ets.tab2list()
    |> Enum.map(fn {_key, m_task} -> m_task end)
    |> Enum.sort_by(fn Model.async_task(index: index) -> index end)
  end
end
