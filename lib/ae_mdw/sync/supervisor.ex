defmodule AeMdw.Sync.Supervisor do
  @moduledoc """
  Supervisor for all sync-related modules.
  """

  use Supervisor

  alias AeMdw.Sync.MemStoreCreator
  alias AeMdw.Sync.Server
  alias AeMdw.Sync.Watcher
  alias AeMdw.Sync.AsyncStoreServer

  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      MemStoreCreator,
      Server,
      Watcher,
      AsyncStoreServer,
      {Task.Supervisor, name: Server.task_supervisor()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
