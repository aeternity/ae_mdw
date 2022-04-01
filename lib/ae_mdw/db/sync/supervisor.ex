defmodule AeMdw.Db.Sync.Supervisor do
  use Supervisor

  ##########

  def start_link(),
    do: start_link([])

  def start_link(args),
    do: Supervisor.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    children = [AeMdw.Db.Sync]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
