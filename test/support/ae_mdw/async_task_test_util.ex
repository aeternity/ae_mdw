defmodule AeMdw.AsyncTaskTestUtil do
  @moduledoc """
  Test helper functions to synchronize with Async Tasks results
  """

  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Db.Model

  require Model

  @spec wakeup_consumer(pos_integer()) :: pid()
  def wakeup_consumer(index) do
    AsyncTasks.Supervisor.start_link([])
    Process.sleep(100)

    {_id, consumer_pid, _type, _mod} =
      AsyncTasks.Supervisor
      |> Supervisor.which_children()
      |> Enum.find(fn {id, _pid, _type, _mod} ->
        id == "Elixir.AeMdw.Sync.AsyncTasks.Consumer#{index}"
      end)

    Process.send(consumer_pid, :demand, [:noconnect])

    consumer_pid
  end

  @spec list_pending() :: [Model.async_task_record()]
  def list_pending do
    :async_tasks_pending
    |> :ets.tab2list()
    |> Enum.map(fn {_key, m_task} -> m_task end)
    |> Enum.sort_by(fn Model.async_task(index: index) -> index end)
  end
end
