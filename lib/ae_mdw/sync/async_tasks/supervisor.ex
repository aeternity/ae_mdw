defmodule AeMdw.Sync.AsyncTasks.Supervisor do
  @moduledoc """
  Supervisor where if the a consumer terminates, the producer state is reset from database.
  """
  use Supervisor

  alias AeMdw.Sync.AsyncTasks.Consumer
  alias AeMdw.Sync.AsyncTasks.Producer
  alias AeMdw.Sync.AsyncTasks.TaskSupervisor

  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl Supervisor
  def init(:ok) do
    children =
      [
        {Task.Supervisor, name: TaskSupervisor},
        Producer
      ] ++ consumers()

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp consumers() do
    for id <- 1..System.schedulers_online() do
      %{
        id: "#{Consumer}#{id}",
        start: {Consumer, :start_link, [[]]}
      }
    end
  end
end
