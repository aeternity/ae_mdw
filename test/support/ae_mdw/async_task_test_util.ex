defmodule AeMdw.AsyncTaskTestUtil do
  @moduledoc """
  Test helper functions to synchronize with Async Tasks results
  """

  alias AeMdw.Sync.AsyncTasks

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
end
