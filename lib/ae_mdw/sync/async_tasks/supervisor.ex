defmodule AeMdw.Sync.AsyncTasks.Supervisor do
  @moduledoc """
  Supervisor where if the a consumer terminates, the producer state is reset from database.
  """
  use Supervisor

  @num_consumers 3

  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl Supervisor
  def init(:ok) do
    children = [
      AeMdw.Sync.AsyncTasks.Producer
      | consumers()
    ]

    AeMdw.Sync.AsyncTasks.Stats.init()
    AeMdw.Sync.AsyncTasks.Store.init()

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp consumers() do
    for id <- 1..@num_consumers do
      %{
        id: id,
        start: {AeMdw.Sync.AsyncTasks.Consumer, :start_link, [[]]}
      }
    end
  end
end
