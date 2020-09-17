defmodule AeMdw.Db.Sync.Supervisor do
  use Supervisor

  alias AeMdw.EtsCache

  ##########

  def start_link(),
    do: start_link([])

  def start_link(args),
    do: Supervisor.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    :ets.new(:name_sync_cache, [:named_table, :ordered_set, :public])
    :ets.new(:oracle_sync_cache, [:named_table, :ordered_set, :public])

    children = [
      AeMdw.Db.Sync,
      AeMdw.Db.Sync.ForkDetector
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
