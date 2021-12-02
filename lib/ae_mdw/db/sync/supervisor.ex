defmodule AeMdw.Db.Sync.Supervisor do
  @moduledoc """
  Supervisor of sync process.
  """
  use Supervisor

  alias AeMdw.Db.Sync.EventsTasksSupervisor

  @spec start_link() :: GenServer.on_start()
  def start_link(),
    do: start_link([])

  @spec start_link(list()) :: GenServer.on_start()
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
