defmodule AeMdw.Db.Sync.Supervisor do
  use Supervisor

  alias AeMdw.Db.Sync.EventsTasksSupervisor

  ##########

  def start_link(),
    do: start_link([])

  def start_link(args),
    do: Supervisor.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    children = [
      {Task.Supervisor, name: EventsTasksSupervisor},
      AeMdw.Db.Sync,
      AeMdw.Db.Sync.GenerationsLoader,
      AeMdw.Db.Sync.GenerationsCache,
      AeMdw.Db.Sync.ForkDetector
    ]

    Supervisor.init(children, max_restarts: 0, strategy: :one_for_one)
  end
end
